with Giflib_Tooling.Session_Types;
with Giflib_Tooling.Source_Units;
with Giflib_Tooling.Validation_Storage_Budgets;

private package Giflib_Tooling.Transition_Storage is
   function Name_Units (Name : String) return Natural;
   function Indexed_Unit_Units
     (Name : String;
      Path : String;
      Clause : Giflib_Tooling.Source_Units.Separate_Clause) return Natural;
   function Clause_Units
     (Name : String;
      Clause : Giflib_Tooling.Source_Units.Separate_Clause) return Natural;
   type Context_Measurement is record
      Copy_Work : Natural := 0;
      Storage_Units : Natural := 0;
   end record;
   function Measure_Context
     (Key : String;
      Context : Giflib_Tooling.Session_Types
        .Type_Classification_Vectors.Vector) return Context_Measurement;
   procedure Charge_Name
     (Storage : in out Giflib_Tooling.Validation_Storage_Budgets.Transaction;
      Name : String);
   procedure Charge_Indexed_Unit
     (Storage : in out Giflib_Tooling.Validation_Storage_Budgets.Transaction;
      Name : String;
      Path : String;
      Clause : Giflib_Tooling.Source_Units.Separate_Clause);
   procedure Charge_Clause
     (Storage : in out Giflib_Tooling.Validation_Storage_Budgets.Transaction;
      Name : String;
      Clause : Giflib_Tooling.Source_Units.Separate_Clause);
end Giflib_Tooling.Transition_Storage;
