with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Source_Model;

private package Giflib_Tooling.Record_Analysis is
   package Syntax renames Giflib_Tooling.Name_Collections;

   function Fields
     (Parsed : Giflib_Tooling.Source_Model.Parsed_Source;
      Type_Name : String) return Syntax.Name_Vectors.Vector;
end Giflib_Tooling.Record_Analysis;
