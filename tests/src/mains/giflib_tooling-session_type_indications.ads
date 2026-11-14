with Ada.Strings.Unbounded;

with Giflib_Tooling.Work_Budgets;
with Giflib_Tooling.Session_State;
with Giflib_Tooling.Session_Types;
with Giflib_Tooling.Source_Tokens;

private package Giflib_Tooling.Session_Type_Indications is
   package Source renames Giflib_Tooling.Source_Tokens;
   package Semantics renames Giflib_Tooling.Session_Types;
   package State renames Giflib_Tooling.Session_State;

   package Budgets renames Giflib_Tooling.Work_Budgets;

   type Indication is record
      Depth : Semantics.Session_Depth := Semantics.No_Session_Depth;
      Declared_Type : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   function Analyze
     (Tokens : Source.Token_Vectors.Vector;
      First : Positive;
      Last : Positive;
      Object : State.State;
      Budget : in out Budgets.Budget) return Indication;
end Giflib_Tooling.Session_Type_Indications;
