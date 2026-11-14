private with Ada.Containers.Vectors;

with Giflib_Tooling.Scope_Analysis;
with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Source_Events;

private package Giflib_Tooling.Suite_Flow is
   type Flow_Map (Valid : Boolean := False) is private;

   function Analyze
     (Tokens : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
      Events : Giflib_Tooling.Source_Events.Structural_Event_Vectors.Vector;
      Ranges :
        Giflib_Tooling.Scope_Analysis.Subprogram_Range_Vectors.Vector;
      Selection_First : Natural;
      Body_First : Natural;
      Last : Natural) return Flow_Map;

   function Is_Nested (Map : Flow_Map; Index : Positive) return Boolean;
   function Is_Unconditional
     (Map : Flow_Map; Index : Positive) return Boolean;
private
   package Boolean_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Boolean);

   type Flow_Map (Valid : Boolean := False) is record
      case Valid is
         when True =>
            First : Positive;
            Nested : Boolean_Vectors.Vector;
            Unconditional : Boolean_Vectors.Vector;
         when False =>
            null;
      end case;
   end record;
end Giflib_Tooling.Suite_Flow;
