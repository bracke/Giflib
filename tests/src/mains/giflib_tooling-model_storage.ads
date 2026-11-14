with Ada.Strings.Unbounded;

with Giflib_Tooling.Model_Storage_Budgets;
with Giflib_Tooling.Source_Events;
with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Source_Units;

private package Giflib_Tooling.Model_Storage is
   procedure Charge_Model
     (Storage : in out Giflib_Tooling.Model_Storage_Budgets.Budget);
   procedure Charge_Token
     (Storage : in out Giflib_Tooling.Model_Storage_Budgets.Budget;
      Text_Length : Natural);
   procedure Charge_Program_Unit
     (Storage : in out Giflib_Tooling.Model_Storage_Budgets.Budget;
      Name : Ada.Strings.Unbounded.Unbounded_String;
      Profile : Ada.Strings.Unbounded.Unbounded_String);
   procedure Charge_Terminal_Event
     (Storage : in out Giflib_Tooling.Model_Storage_Budgets.Budget);
   procedure Charge_Named_Event
     (Storage : in out Giflib_Tooling.Model_Storage_Budgets.Budget;
      Name : Ada.Strings.Unbounded.Unbounded_String);
   procedure Charge_Subprogram_Event
     (Storage : in out Giflib_Tooling.Model_Storage_Budgets.Budget;
      Name : Ada.Strings.Unbounded.Unbounded_String;
      Profile : Ada.Strings.Unbounded.Unbounded_String);
   procedure Charge_Separate_Clause
     (Storage : in out Giflib_Tooling.Model_Storage_Budgets.Budget;
      Parent_Length : Natural);
   function Measure
     (Tokens : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
      Units : Giflib_Tooling.Source_Units.Program_Unit_Vectors.Vector;
      Events : Giflib_Tooling.Source_Events.Structural_Event_Vectors.Vector;
      Clause : Giflib_Tooling.Source_Units.Separate_Clause) return Natural;
end Giflib_Tooling.Model_Storage;
