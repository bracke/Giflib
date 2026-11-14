private with Ada.Containers.Vectors;

with Giflib_Tooling.Scope_Analysis;

private package Giflib_Tooling.Suite_Flow_Ranges is
   type Tracker is private;
   procedure Initialize
     (Object : out Tracker;
      Ranges : Giflib_Tooling.Scope_Analysis.Subprogram_Range_Vectors.Vector);
   function Is_Nested
     (Object : in out Tracker;
      Ranges : Giflib_Tooling.Scope_Analysis.Subprogram_Range_Vectors.Vector;
      Index : Positive;
      Selection_First : Positive) return Boolean;
private
   package Positive_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Positive);
   type Optional_Cursor (Present : Boolean := False) is record
      case Present is
         when True =>
            Value : Positive;
         when False =>
            null;
      end case;
   end record;
   type Tracker is record
      Active_Ends : Positive_Vectors.Vector;
      Cursor : Optional_Cursor;
   end record;
end Giflib_Tooling.Suite_Flow_Ranges;
