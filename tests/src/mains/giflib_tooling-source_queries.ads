with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Source_Units;
with Giflib_Tooling.Work_Budgets;

private package Giflib_Tooling.Source_Queries is
   package Source renames Giflib_Tooling.Source_Tokens;

   function Separate_Clause_Of
     (Tokens : Source.Token_Vectors.Vector;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget;
      Before_Retain : access procedure (Amount : Natural) := null)
      return Giflib_Tooling.Source_Units.Separate_Clause;
end Giflib_Tooling.Source_Queries;
