with Giflib_Tooling.Session_Identity;
with Giflib_Tooling.Session_Types;
with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Work_Budgets;

private package Giflib_Tooling.Session_Queries is
   function Package_Type_Context
     (Parsed : Giflib_Tooling.Source_Model.Parsed_Source;
      Target_Type : Giflib_Tooling.Session_Identity.Target;
      Initial_Context :
        Giflib_Tooling.Session_Types.Type_Classification_Vectors.Vector;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget;
      Unit_Scope : String := "")
      return Giflib_Tooling.Session_Types.Type_Classification_Vectors.Vector;
end Giflib_Tooling.Session_Queries;
