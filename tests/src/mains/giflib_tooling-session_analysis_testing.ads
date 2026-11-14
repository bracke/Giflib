with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Session_Identity;
with Giflib_Tooling.Session_Types;
with Giflib_Tooling.Source_Tokens;

private package Giflib_Tooling.Session_Analysis_Testing is
   procedure Scan
     (Text : String;
      Target_Type : Giflib_Tooling.Session_Identity.Target;
      Type_Context :
        Giflib_Tooling.Session_Types.Type_Classification_Vectors.Vector;
      Process : not null access procedure
        (Statement : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
         Session_Names : Giflib_Tooling.Name_Collections.Name_Vectors.Vector);
      Unit_Scope : String := "");
end Giflib_Tooling.Session_Analysis_Testing;
