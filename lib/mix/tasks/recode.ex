defmodule Mix.Tasks.Recode do
  @shortdoc "Runs the linter"

  @moduledoc """
  #{@shortdoc}.

  ```shell
  > mix recode [options] [inputs]
  ```

  Without a `inputs` argument the `inputs` value from the config is used. The
  `inputs` argument accepts a wildcard.

  If `inputs` value is `-`, then the input is read from stdin.

  Without the option `--config file` the config file `.recode.exs` is used. A
  default `.recode.exs` can be generated with `mix recode.gen.config`.

  ## Command line Option

    * `-a`, `--autocorrect`, `--no-autocorrect` - Activates/deactivates
      autocrrection. Overwrites the corresponding value in the configuration.

    * `-c`, `--config` - specifies an alternative config file.

    * `-d`, `--dry`, `--no-dry` - Activates/deactivates the dry mode. No file is
      overwritten in dry mode. Overwrites the corresponding value in the
      configuration.

    * `-v`, `--verbose`, `--no-verbose` - Activate/deactivates the verbose mode.
      Overwrites the corresponding value in the configuration.

    * `-t`, `--task`, specifies the task to use. With this option, the task is
      used even if it is specified as `active:  false` in the configuration.
      This option can appear multiple times in a call.
  """

  use Mix.Task
  use Recode.StopWatch

  import Recode.IO

  alias Recode.Config
  alias Recode.Runner
  alias Rewrite.Source

  @opts strict: [
          autocorrect: :boolean,
          config: :string,
          dry: :boolean,
          task: :keep,
          verbose: :boolean
        ],
        aliases: [
          a: :autocorrect,
          c: :config,
          d: :dry,
          t: :task,
          v: :verbose
        ]

  @impl Mix.Task
  @spec run(list()) :: no_return()
  def run(opts) do
    _stop_watch = StopWatch.init!()
    StopWatch.start!(:recode)

    opts = opts!(opts)

    opts =
      opts
      |> Keyword.get(:config, ".recode.exs")
      |> config!()
      |> validate_config!()
      |> validate_tasks!()
      |> update_task_configs!()
      |> Keyword.merge(Keyword.take(opts, [:verbose, :autocorrect, :dry, :inputs]))
      |> Keyword.put(:cli_opts, acc_tasks(opts))
      |> update(:verbose)

    opts
    |> Runner.run()
    |> output(opts[:tasks])
  end

  @spec output(Rewrite.t(), keyword()) :: no_return()
  defp output(%Rewrite{sources: sources}, _opts) when map_size(sources) == 0 do
    Mix.raise("No sources found")
  end

  defp output(%Rewrite{} = project, tasks) do
    reason =
      case Rewrite.issues?(project) do
        false -> :normal
        true -> {:shutdown, exit_code(project, tasks)}
      end

    time = (StopWatch.time!(:recode) / 1_000) |> Float.round(2) |> max(0.01)
    puts([:info, "Finished in #{inspect(time)} seconds."])

    exit(reason)
  end

  defp opts!(opts) do
    case OptionParser.parse!(opts, @opts) do
      {opts, []} -> opts
      {opts, inputs} -> Keyword.put(opts, :inputs, inputs)
    end
  end

  defp exit_code(project, tasks) do
    exit_codes =
      Enum.into(tasks, %{}, fn {task, config} -> {task, Keyword.get(config, :exit_code, 1)} end)

    Enum.reduce(Rewrite.sources(project), 0, fn source, exit_code ->
      source
      |> Source.issues()
      |> Enum.reduce(exit_code, fn issue, exit_code ->
        Bitwise.bor(exit_code, Map.get(exit_codes, issue.reporter, 1))
      end)
    end)
  end

  defp acc_tasks(opts) do
    tasks =
      Enum.reduce(opts, [], fn {key, value}, acc ->
        case key do
          :task -> [value | acc]
          _else -> acc
        end
      end)

    opts
    |> Keyword.delete(:task)
    |> Keyword.put(:tasks, tasks)
  end

  defp config!(opts) do
    case Config.read(opts) do
      {:ok, config} ->
        config

      {:error, :not_found} ->
        Mix.raise("Config file not found. Run `mix recode.gen.config` to create `.recode.exs`.")
    end
  end

  defp validate_config!(config) do
    case Config.validate(config) do
      :ok ->
        config

      {:error, :out_of_date} ->
        Mix.raise("The config is out of date. Run `mix recode.update.config` to update.")

      {:error, :no_tasks} ->
        Mix.raise("No `:tasks` key found in configuration.")
    end
  end

  defp validate_tasks!(config) do
    Enum.each(config[:tasks], fn {task, _config} ->
      task |> Code.ensure_loaded() |> validate_task!(task)
    end)

    config
  end

  defp validate_task!({:error, :nofile}, task) do
    Mix.raise("Recode task #{inspect(task)} not found.")
  end

  defp validate_task!({:module, _module}, task) do
    unless Recode.Task in task.__info__(:attributes)[:behaviour] do
      Mix.raise("The module #{inspect(task)} does not implement the Recode.Task behaviour.")
    end
  end

  defp update_task_configs!(config) do
    Keyword.update!(config, :tasks, fn tasks ->
      Enum.map(tasks, fn {task, config} ->
        task_config = Keyword.get(config, :config, [])

        case task.init(task_config) do
          {:ok, task_config} ->
            {task, Keyword.put(config, :config, task_config)}

          {:error, message} ->
            Mix.raise("The task #{inspect(task)} has an invalid config:\n#{message}")
        end
      end)
    end)
  end

  defp update(opts, :verbose) do
    case opts[:dry] do
      true -> Keyword.put(opts, :verbose, true)
      false -> opts
    end
  end
end
