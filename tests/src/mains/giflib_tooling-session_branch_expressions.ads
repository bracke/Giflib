with Giflib_Tooling.Work_Budgets;
with Giflib_Tooling.Session_Call_Arguments;
with Giflib_Tooling.Session_State;
with Giflib_Tooling.Source_Tokens;

private package Giflib_Tooling.Session_Branch_Expressions is
   package Budgets renames Giflib_Tooling.Work_Budgets;
   package Call_Arguments renames Giflib_Tooling.Session_Call_Arguments;
   package Source renames Giflib_Tooling.Source_Tokens;
   package State renames Giflib_Tooling.Session_State;

   function Case_Result
     (Tokens : Source.Token_Vectors.Vector;
      First : Positive;
      Last : Positive;
      Object : State.State;
      Budget : in out Budgets.Budget;
      Resolve : Call_Arguments.Resolver_Access) return State.Relation;
   function Conditional_Result
     (Tokens : Source.Token_Vectors.Vector;
      First : Positive;
      Last : Positive;
      Object : State.State;
      Budget : in out Budgets.Budget;
      Resolve : Call_Arguments.Resolver_Access) return State.Relation;
end Giflib_Tooling.Session_Branch_Expressions;
