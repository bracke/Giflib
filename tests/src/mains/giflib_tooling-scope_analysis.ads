with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Work_Budgets;

private package Giflib_Tooling.Scope_Analysis is
   package Source renames Giflib_Tooling.Source_Model;

   type Subprogram_Range (Complete : Boolean := False) is record
      Name : Ada.Strings.Unbounded.Unbounded_String;
      Profile : Ada.Strings.Unbounded.Unbounded_String;
      First : Positive;
      Depth : Natural := 0;
      Directly_In_Package : Boolean := False;
      Is_Generic : Boolean := False;
      case Complete is
         when True =>
            Body_First : Positive;
            Last : Positive;
         when False =>
            null;
      end case;
   end record;
   package Subprogram_Range_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Subprogram_Range);

   type Declaration_Scope is
     (Outside_Declaration_Scope, Package_Unit_Declaration, Nested_Declaration);
   package Declaration_Scope_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Declaration_Scope);

   function Declaration_Scopes
     (Parsed : Source.Parsed_Source;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget)
      return Declaration_Scope_Vectors.Vector;

   procedure Scan_Declarations
     (Parsed : Source.Parsed_Source;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget;
      Process : not null access procedure
        (Statement : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
         Scope_At : Declaration_Scope_Vectors.Vector));

   function Subprogram_Ranges
     (Parsed : Source.Parsed_Source;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget)
      return Subprogram_Range_Vectors.Vector;
end Giflib_Tooling.Scope_Analysis;
