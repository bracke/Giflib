with Giflib_Tooling.Work_Budgets;
with Giflib_Tooling.Session_State;
with Giflib_Tooling.Session_Types;
with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Source_Events;

private package Giflib_Tooling.Session_Callable_Declarations is
   package Source renames Giflib_Tooling.Source_Tokens;
   package Syntax renames Giflib_Tooling.Source_Events;
   package Semantics renames Giflib_Tooling.Session_Types;
   package State renames Giflib_Tooling.Session_State;
   package Budgets renames Giflib_Tooling.Work_Budgets;

   procedure Add
     (Tokens : Source.Token_Vectors.Vector;
      Event : Syntax.Subprogram_Event;
      Object : in out State.State;
      Context : in out Semantics.Type_Classification_Vectors.Vector;
      Budget : in out Budgets.Budget;
      Unit_Scope : String := "");
end Giflib_Tooling.Session_Callable_Declarations;
