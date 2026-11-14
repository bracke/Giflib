with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

private package Giflib_Tooling.Name_Collections is
   use Ada.Strings.Unbounded;
   package Name_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive,
      Element_Type => Unbounded_String);

   function Contains
     (Names : Name_Vectors.Vector; Name : String) return Boolean;
   function Value (Name : Unbounded_String) return String;
end Giflib_Tooling.Name_Collections;
