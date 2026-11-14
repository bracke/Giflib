with Giflib_Tooling.Source_Events;
with Giflib_Tooling.Source_Limits;
with Giflib_Tooling.Model_Storage_Budgets;
with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Work_Budgets;

private package Giflib_Tooling.Structural_Event_Builder is
   procedure Build
     (Tokens : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
      Events : out Giflib_Tooling.Source_Events.Structural_Event_Vectors.Vector;
      Limits : Giflib_Tooling.Source_Limits.Parsing_Limits;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget;
      Storage : in out Giflib_Tooling.Model_Storage_Budgets.Budget);
end Giflib_Tooling.Structural_Event_Builder;
