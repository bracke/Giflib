with Giflib_Tooling.Work_Budgets;
with Giflib_Tooling.Session_State;
with Giflib_Tooling.Session_Types;
with Giflib_Tooling.Source_Tokens;

private package Giflib_Tooling.Session_Call_Arguments is
   package Budgets renames Giflib_Tooling.Work_Budgets;
   package Semantics renames Giflib_Tooling.Session_Types;
   package Source renames Giflib_Tooling.Source_Tokens;
   package State renames Giflib_Tooling.Session_State;

   type Resolver_Access is not null access function
     (Tokens : Source.Token_Vectors.Vector;
      First : Positive;
      Last : Positive;
      Object : State.State;
      Budget : in out Budgets.Budget) return State.Relation;

   type Argument_Analysis (Valid : Boolean := False) is record
      case Valid is
         when True =>
            Closing : Positive;
            Types : Semantics.Formal_Type_Vectors.Vector;
         when False =>
            null;
      end case;
   end record;

   function Analyze
     (Tokens : Source.Token_Vectors.Vector;
      Callable_Index : Positive;
      Last : Positive;
      Object : State.State;
      Budget : in out Budgets.Budget;
      Resolve : Resolver_Access) return Argument_Analysis;
end Giflib_Tooling.Session_Call_Arguments;
