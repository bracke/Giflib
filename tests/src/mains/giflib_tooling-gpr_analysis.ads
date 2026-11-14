with Giflib_Tooling.Name_Collections;

private package Giflib_Tooling.GPR_Analysis is
   function Has_With (Text : String; Project_Path : String) return Boolean;
   function Attribute_Strings
     (Text : String; Attribute_Name : String)
      return Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
end Giflib_Tooling.GPR_Analysis;
