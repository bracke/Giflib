with Giflib_Tooling.Work_Budgets;
with Giflib_Tooling.Session_State;
with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Name_Collections;

private package Giflib_Tooling.Session_Expression_Selections is
   package Budgets renames Giflib_Tooling.Work_Budgets;
   package Source renames Giflib_Tooling.Source_Tokens;
   package Syntax renames Giflib_Tooling.Name_Collections;
   package State renames Giflib_Tooling.Session_State;

   function Apply
     (Tokens : Source.Token_Vectors.Vector;
      Initial : State.Relation;
      Start : Natural;
      Last : Positive;
      Object : State.State;
      Budget : in out Budgets.Budget) return State.Relation;
end Giflib_Tooling.Session_Expression_Selections;
