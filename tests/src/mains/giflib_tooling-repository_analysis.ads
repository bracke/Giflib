with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Work_Budgets;

private package Giflib_Tooling.Repository_Analysis is
   function Declares_Main
     (Parsed : Giflib_Tooling.Source_Model.Parsed_Source;
      Expected_Name : String;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget) return Boolean;

   function Documented_Executables
     (Text : String)
      return Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
end Giflib_Tooling.Repository_Analysis;
