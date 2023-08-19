defmodule Recode.Task.TagTODOTest do
  use RecodeCase

  alias Recode.Task.TagTODO

  describe "run/1" do
    #
    # cases NOT raising issues
    #

    test "does not trigger" do
      ~s'''
      defmodule TODO do
        @moduledoc """
        The TODO module
        """

        # Returns TODO atom
        def todo(x), do: :TODO
      end
      '''
      |> run_task(TagTODO)
      |> refute_issues()
    end

    test "does not triggers tags in doc when deactivated" do
      ~s'''
      defmodule TODO do
        @moduledoc """
        The TODO module
        TODO add examples
        """

        def todo(x), do: :TODO
      end
      '''
      |> run_task(TagTODO, include_docs: false)
      |> refute_issues()
    end

    #
    # cases NOT raising issues
    #

    test "triggers an issue for a tag in comment" do
      ~s'''
      defmodule TODO do
        @moduledoc """
        The TODO module
        """

        # TODO: add spec
        def todo(x), do: :TODO
      end
      '''
      |> run_task(TagTODO)
      |> assert_issue_with(
        reporter: TagTODO,
        line: 6,
        message: "Found a tag: TODO: add spec"
      )
    end
  end

  describe "init/1" do
    test "returns an ok tuple with added defaults" do
      assert TagTODO.init(tag: "TODO", reporter: TagTODO) ==
               {:ok, include_docs: true, tag: "TODO", reporter: TagTODO}
    end

    test "returns an ok tuple" do
      assert TagTODO.init(tag: "TODO", reporter: TagTODO, include_docs: false) ==
               {:ok, tag: "TODO", reporter: TagTODO, include_docs: false}
    end
  end
end
