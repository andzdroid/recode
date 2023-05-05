defmodule Recode.FormatterPlugin do
  @moduledoc """
  Defines Recode formatter plugin for `mix format`.

  Since Elixir 1.13, it is possible to define custom formatter plugins. This
  plugin allows you to run Recode autocorrecting tasks together when executing
  `mix format`.

  To use this formatter, simply add `Recode.FormatterPlugin` to your
  `.formatter.exs` plugins:

  ```
    [
      inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
      plugins: [Recode.FormatterPlugin]
    ]
  ```

  By default it uses the `.recode.exs` configuration file.

  If your project does not have a `.recode.exs` configuration file or if you
  want to overwrite the configuration, you can pass the configuration using the
  `recode` option:

  ```
    [
      inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
      plugins: [Recode.FormatterPlugin],
      recode: [
        tasks: [
          {Recode.Task.AliasExpansion, []},
          {Recode.Task.EnforceLineLength, []},
          {Recode.Task.SinglePipe, []}
        ]
      ]
    ]
  ```
  """

  @behaviour Mix.Tasks.Format

  alias Recode.Config

  @table :recode_formatter_plugin

  @impl true
  def features(opts) do
    # This callback will be applied for every file the Elixir formater wants to
    # format. All calls comming from one Process.
    # Here it is a little misappropriated as `&init/1`.
    _ref = init(opts[:recode])

    [extensions: [".ex", ".exs"]]
  end

  @impl true
  def format(content, opts) do
    if seen?(opts[:file]) do
      content
    else
      Recode.Runner.run(content, config())
    end
  end

  defp seen?(file) do
    case :ets.lookup(@table, file) do
      [] ->
        :ets.insert(@table, {file})
        false

      _seen ->
        true
    end
  end

  defp config do
    with [{:config, config}] <- :ets.lookup(@table, :config) do
      config
    end
  end

  defp init(recode) do
    with :undefined <- :ets.whereis(@table) do
      _ref = :ets.new(@table, [:set, :public, :named_table])
      :ets.insert(@table, {:config, init_config(recode)})
    end
  end

  @config_error """
  No configuration for `Recode.FormatterPlugin` found. Run \
  `mix recode.get.config` to create a config file or add config in \
  `.formatter.exs` under the key `:recode`.
  """
  defp init_config(nil) do
    case Config.read() do
      {:error, :not_found} ->
        Mix.raise(@config_error)

      {:ok, config} ->
        config
        |> validate_config!()
        |> init_config()
    end
  end

  defp init_config(recode) do
    Keyword.merge(recode, dry: false, verbose: false, autocorrect: true, check: false)
  end

  defp validate_config!(config) do
    case Config.validate(config) do
      :ok ->
        config

      {:error, :out_of_date} ->
        Mix.raise("The config is out of date. Run `mix recode.gen.config` to update.")
    end
  end
end
