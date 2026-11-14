with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Structural_Types;
with Giflib_Tooling.Work_Budgets;

private package Giflib_Tooling.Structural_Subprograms is
   package Source renames Giflib_Tooling.Source_Tokens;

   subtype Subprogram_Info is
     Giflib_Tooling.Structural_Types.Subprogram_Header;

   function Analyze
     (Tokens : Source.Token_Vectors.Vector;
      Start : Positive;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget)
      return Subprogram_Info;
end Giflib_Tooling.Structural_Subprograms;
