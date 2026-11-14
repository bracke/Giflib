with Giflib_Tooling.Work_Budgets;
with Giflib_Tooling.Session_State;
with Giflib_Tooling.Session_Types;
with Giflib_Tooling.Source_Tokens;

private package Giflib_Tooling.Session_Record_Declarations is
   package Source renames Giflib_Tooling.Source_Tokens;
   package Semantics renames Giflib_Tooling.Session_Types;
   package State renames Giflib_Tooling.Session_State;
   package Budgets renames Giflib_Tooling.Work_Budgets;

   procedure Add
     (Tokens : Source.Token_Vectors.Vector;
      Record_Index : Positive;
      Owner_Type : String;
      Object : in out State.State;
      Context : in out Semantics.Type_Classification_Vectors.Vector;
      Budget : in out Budgets.Budget;
      Unit_Scope : String);
end Giflib_Tooling.Session_Record_Declarations;
