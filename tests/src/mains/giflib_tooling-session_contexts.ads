with Ada.Strings.Unbounded;

with Giflib_Tooling.Work_Budgets;
with Giflib_Tooling.Session_Types;

private package Giflib_Tooling.Session_Contexts is
   package Semantics renames Giflib_Tooling.Session_Types;
   package Budgets renames Giflib_Tooling.Work_Budgets;

   procedure Set_Type
     (Context : in out Semantics.Type_Classification_Vectors.Vector;
      Name : Ada.Strings.Unbounded.Unbounded_String;
      Depth : Semantics.Session_Depth;
      Declared_Type : Ada.Strings.Unbounded.Unbounded_String;
      Related_Type : Ada.Strings.Unbounded.Unbounded_String;
      Budget : in out Budgets.Budget);
   procedure Set_Component
     (Context : in out Semantics.Type_Classification_Vectors.Vector;
      Name : Ada.Strings.Unbounded.Unbounded_String;
      Depth : Semantics.Session_Depth;
      Declared_Type : Ada.Strings.Unbounded.Unbounded_String;
      Owner_Type : Ada.Strings.Unbounded.Unbounded_String;
      Budget : in out Budgets.Budget);
   procedure Set_Callable
     (Context : in out Semantics.Type_Classification_Vectors.Vector;
      Name : Ada.Strings.Unbounded.Unbounded_String;
      Depth : Semantics.Session_Depth;
      Declared_Type : Ada.Strings.Unbounded.Unbounded_String;
      Scope_Name : Ada.Strings.Unbounded.Unbounded_String;
      Profile : Semantics.Callable_Profile;
      Budget : in out Budgets.Budget);
   procedure Set_Package
     (Context : in out Semantics.Type_Classification_Vectors.Vector;
      Name : Ada.Strings.Unbounded.Unbounded_String;
      Target_Scope : Ada.Strings.Unbounded.Unbounded_String;
      Budget : in out Budgets.Budget);
end Giflib_Tooling.Session_Contexts;
