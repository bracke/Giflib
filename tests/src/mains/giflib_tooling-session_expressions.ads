with Giflib_Tooling.Work_Budgets;
with Giflib_Tooling.Session_State;
with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Name_Collections;

private package Giflib_Tooling.Session_Expressions is
   package Source renames Giflib_Tooling.Source_Tokens;
   package Syntax renames Giflib_Tooling.Name_Collections;
   package State renames Giflib_Tooling.Session_State;
   package Budgets renames Giflib_Tooling.Work_Budgets;

   function Iterable_Relation
     (Tokens : Source.Token_Vectors.Vector;
      First : Positive;
      Object : State.State;
      Budget : in out Budgets.Budget) return State.Relation;
end Giflib_Tooling.Session_Expressions;
