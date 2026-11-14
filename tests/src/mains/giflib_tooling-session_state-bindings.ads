with Ada.Strings.Unbounded;

package Giflib_Tooling.Session_State.Bindings is
   procedure Bind_Object
     (Object : in out State;
      Name : Ada.Strings.Unbounded.Unbounded_String;
      Session_Nesting : Semantics.Session_Depth;
      Budget : in out Budgets.Budget;
      Declared_Type : String := "");
   procedure Bind_Type
     (Object : in out State;
      Name : Ada.Strings.Unbounded.Unbounded_String;
      Session_Nesting : Semantics.Session_Depth;
      Declared_Type : String;
      Budget : in out Budgets.Budget;
      Related_Type : String := "");
   procedure Bind_Component
     (Object : in out State;
      Name : Ada.Strings.Unbounded.Unbounded_String;
      Session_Nesting : Semantics.Session_Depth;
      Declared_Type : String;
      Owner_Type : String;
      Budget : in out Budgets.Budget);
   procedure Bind_Callable
     (Object : in out State;
      Name : Ada.Strings.Unbounded.Unbounded_String;
      Session_Nesting : Semantics.Session_Depth;
      Declared_Type : String;
      Callable_Scope : String;
      Callable_Profile : Semantics.Callable_Profile;
      Budget : in out Budgets.Budget);
   procedure Bind_Package
     (Object : in out State;
      Name : String;
      Budget : in out Budgets.Budget;
      Target : String := "");
   procedure Add_Implicit_Package_Binding
     (Object : in out State;
      Name : String;
      Target : String;
      Budget : in out Budgets.Budget);
end Giflib_Tooling.Session_State.Bindings;
