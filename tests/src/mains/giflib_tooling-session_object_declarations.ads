with Giflib_Tooling.Work_Budgets;
with Giflib_Tooling.Session_State;
with Giflib_Tooling.Source_Tokens;

private package Giflib_Tooling.Session_Object_Declarations is
   package Source renames Giflib_Tooling.Source_Tokens;
   package State renames Giflib_Tooling.Session_State;
   package Budgets renames Giflib_Tooling.Work_Budgets;

   procedure Add
     (Tokens : Source.Token_Vectors.Vector;
      Statement : Source.Token_Vectors.Vector;
      Colon : Positive;
      Object : in out State.State;
      Budget : in out Budgets.Budget);
end Giflib_Tooling.Session_Object_Declarations;
