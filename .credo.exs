%{
  configs: [
    %{
      name: "default",

      files: %{
        included: ["lib"],
      },

      checks: [
        {Credo.Check.Consistency.TabsOrSpaces},
        {Credo.Check.Readability.MaxLineLength, false},
      ]
    }
  ]
}
