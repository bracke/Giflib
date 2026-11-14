with Giflib_Tooling.Work_Budgets;
with Giflib_Tooling.Session_State;
with Giflib_Tooling.Session_Types;
with Giflib_Tooling.Source_Tokens;

private package Giflib_Tooling.Session_Lexical_Events is
   package Source renames Giflib_Tooling.Source_Tokens;
   package Semantics renames Giflib_Tooling.Session_Types;
   package State renames Giflib_Tooling.Session_State;
   package Budgets renames Giflib_Tooling.Work_Budgets;

   procedure Apply
     (Tokens : Source.Token_Vectors.Vector;
      Statement : Source.Token_Vectors.Vector;
      Index : Positive;
      Object : in out State.State;
      Discovered_Context : in out
        Semantics.Type_Classification_Vectors.Vector;
      Budget : in out Budgets.Budget;
      Unit_Scope : String);
   procedure Finish_Statement
     (Object : in out State.State;
      Parenthesis_Depth : Natural;
      Budget : in out Budgets.Budget);
end Giflib_Tooling.Session_Lexical_Events;
