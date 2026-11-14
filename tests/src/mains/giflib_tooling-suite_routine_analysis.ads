with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Work_Budgets;

private package Giflib_Tooling.Suite_Routine_Analysis is
   function Registers_Test_Routine
     (Parsed : Giflib_Tooling.Source_Model.Parsed_Source;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget) return Boolean;
end Giflib_Tooling.Suite_Routine_Analysis;
