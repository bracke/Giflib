with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

private package Giflib_Tooling.Source_Units is
   use Ada.Strings.Unbounded;
   type Separate_Clause_Kind is
     (No_Separate_Clause, Valid_Separate_Clause, Malformed_Separate_Clause);
   type Separate_Clause
     (Kind : Separate_Clause_Kind := No_Separate_Clause) is record
      case Kind is
         when Valid_Separate_Clause =>
            Parent : Unbounded_String;
         when No_Separate_Clause | Malformed_Separate_Clause =>
            null;
      end case;
   end record;
   type Program_Unit_Kind is (Subprogram_Unit, Package_Unit);
   type Program_Unit is record
      Kind : Program_Unit_Kind := Subprogram_Unit;
      Name : Unbounded_String;
      Profile : Unbounded_String;
      Is_Nested : Boolean := False;
      Is_Body : Boolean := False;
   end record;
   package Program_Unit_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Program_Unit);
end Giflib_Tooling.Source_Units;
