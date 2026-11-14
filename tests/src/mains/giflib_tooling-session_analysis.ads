with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Session_Identity;
with Giflib_Tooling.Session_Types;
with Giflib_Tooling.Work_Budgets;

private package Giflib_Tooling.Session_Analysis is
   procedure Scan
     (Parsed : Giflib_Tooling.Source_Model.Parsed_Source;
      Target_Type : Giflib_Tooling.Session_Identity.Target;
      Type_Context :
        Giflib_Tooling.Session_Types.Type_Classification_Vectors.Vector;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget;
      Process : not null access procedure
        (Statement : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
         Session_Names : Giflib_Tooling.Name_Collections.Name_Vectors.Vector);
      Unit_Scope : String := "");

end Giflib_Tooling.Session_Analysis;
