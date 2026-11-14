with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Work_Budgets;

private package Giflib_Tooling.Structural_Bodies is
   package Source renames Giflib_Tooling.Source_Tokens;

   function Is_Body_Marker
     (Tokens : Source.Token_Vectors.Vector; Index : Positive) return Boolean;
   function Introduces_Body
     (Tokens : Source.Token_Vectors.Vector;
      Start : Positive;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget) return Boolean;
end Giflib_Tooling.Structural_Bodies;
