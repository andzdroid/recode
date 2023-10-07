alias Recode.Task

[
  # Can also be set/reset with "--autocorrect"/"--no-autocorrect".
  autocorrect: true,
  # With "--dry" no changes will be written to the files.
  # Can also be set/reset with "--dry"/"--no-dry".
  # If dry is true then verbose is also active.
  dry: false,
  # Can also be set/reset with "--verbose"/"--no-verbose".
  verbose: false,
  inputs: ["{config,lib,test}/**/*.{ex,exs}"],
  formatters: [Recode.CLIFormatter],
  tasks: [
    {Task.SinglePipe, []},
    {Task.PipeFunOne, []},
    {Task.AliasExpansion, []}
  ]
]
