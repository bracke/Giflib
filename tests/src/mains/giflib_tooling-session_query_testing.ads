with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Session_Identity;
with Giflib_Tooling.Session_Types;

private package Giflib_Tooling.Session_Query_Testing is
   function Package_Type_Context
     (Text : String;
      Target_Type : Giflib_Tooling.Session_Identity.Target;
      Initial_Context :
        Giflib_Tooling.Session_Types.Type_Classification_Vectors.Vector;
      Unit_Scope : String := "")
      return Giflib_Tooling.Session_Types.Type_Classification_Vectors.Vector;
   function Identifiers
     (Text : String;
      Target_Type : Giflib_Tooling.Session_Identity.Target)
      return Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
   function Identifiers_At
     (Text : String;
      Target_Type : Giflib_Tooling.Session_Identity.Target;
      Position : Natural)
      return Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
end Giflib_Tooling.Session_Query_Testing;
