with Giflib_Tooling.Work_Budgets;
with Giflib_Tooling.Session_Identity;
with Giflib_Tooling.Session_State;
with Giflib_Tooling.Session_Types;
with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Source_Events;

private package Giflib_Tooling.Session_Semantic_Events is
   package Source renames Giflib_Tooling.Source_Tokens;
   package Syntax renames Giflib_Tooling.Source_Events;
   package Semantics renames Giflib_Tooling.Session_Types;
   package State renames Giflib_Tooling.Session_State;
   package Budgets renames Giflib_Tooling.Work_Budgets;
   package Identity renames Giflib_Tooling.Session_Identity;

   procedure Initialize
     (Object : in out State.State;
      Target_Type : Identity.Target;
      Budget : in out Budgets.Budget;
      Initial_Context : Semantics.Type_Classification_Vectors.Vector);
   procedure Apply
     (Tokens : Source.Token_Vectors.Vector;
      Statement : Source.Token_Vectors.Vector;
      Index : Positive;
      Event : Syntax.Structural_Event;
      Object : in out State.State;
      Discovered_Context : in out
        Semantics.Type_Classification_Vectors.Vector;
      Budget : in out Budgets.Budget;
      Unit_Scope : String);
   procedure Finish_Statement
     (Object : in out State.State;
      Parenthesis_Depth : Natural;
      Budget : in out Budgets.Budget);
end Giflib_Tooling.Session_Semantic_Events;
