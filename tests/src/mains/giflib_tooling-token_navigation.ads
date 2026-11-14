with Giflib_Tooling.Work_Budgets;
with Giflib_Tooling.Source_Tokens;

private package Giflib_Tooling.Token_Navigation is
   package Source renames Giflib_Tooling.Source_Tokens;
   package Budgets renames Giflib_Tooling.Work_Budgets;

   subtype Optional_Position is Source.Optional_Position;

   function Before_Semicolon
     (Tokens : Source.Token_Vectors.Vector;
      First : Positive;
      Value : String;
      Budget : in out Budgets.Budget) return Optional_Position;
   function Before_Outer_Semicolon
     (Tokens : Source.Token_Vectors.Vector;
      First : Positive;
      Value : String;
      Budget : in out Budgets.Budget) return Optional_Position;
   function Is_Outer_Group
     (Tokens : Source.Token_Vectors.Vector;
      First : Positive;
      Last : Positive;
      Budget : in out Budgets.Budget) return Boolean;
end Giflib_Tooling.Token_Navigation;
