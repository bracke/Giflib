with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Source_Model;

private package Giflib_Tooling.Ada_Context_Clauses is
   function Units
     (Text : String) return Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
   function Units
     (Parsed : Giflib_Tooling.Source_Model.Parsed_Source)
      return Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
end Giflib_Tooling.Ada_Context_Clauses;
