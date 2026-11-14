with Giflib_Tooling.Work_Budgets;
with Giflib_Tooling.Session_State;
with Giflib_Tooling.Source_Tokens;

private package Giflib_Tooling.Session_Expression_Resolution is
   package Source renames Giflib_Tooling.Source_Tokens;
   package State renames Giflib_Tooling.Session_State;
   package Budgets renames Giflib_Tooling.Work_Budgets;

   function Resolve
     (Tokens : Source.Token_Vectors.Vector;
      First : Positive;
      Last : Positive;
      Object : State.State;
      Budget : in out Budgets.Budget) return State.Relation;
end Giflib_Tooling.Session_Expression_Resolution;
