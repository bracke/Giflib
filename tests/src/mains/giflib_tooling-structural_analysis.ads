with Giflib_Tooling.Source_Events;
with Giflib_Tooling.Source_Limits;
with Giflib_Tooling.Model_Storage_Budgets;
with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Source_Units;
with Giflib_Tooling.Work_Budgets;

private package Giflib_Tooling.Structural_Analysis is
   package Tokens renames Giflib_Tooling.Source_Tokens;
   package Events renames Giflib_Tooling.Source_Events;
   package Units renames Giflib_Tooling.Source_Units;
   package Limits renames Giflib_Tooling.Source_Limits;

   procedure Analyze
     (Tokens : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
      Events : out Giflib_Tooling.Source_Events.Structural_Event_Vectors.Vector;
      Units : out Giflib_Tooling.Source_Units.Program_Unit_Vectors.Vector;
      Clause : out Giflib_Tooling.Source_Units.Separate_Clause;
      Limits : Giflib_Tooling.Source_Limits.Parsing_Limits :=
        Giflib_Tooling.Source_Limits.Default_Parsing_Limits);
   procedure Analyze
     (Tokens : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
      Events : out Giflib_Tooling.Source_Events.Structural_Event_Vectors.Vector;
      Units : out Giflib_Tooling.Source_Units.Program_Unit_Vectors.Vector;
      Clause : out Giflib_Tooling.Source_Units.Separate_Clause;
      Limits : Giflib_Tooling.Source_Limits.Parsing_Limits;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget;
      Storage : in out Giflib_Tooling.Model_Storage_Budgets.Budget);
end Giflib_Tooling.Structural_Analysis;
