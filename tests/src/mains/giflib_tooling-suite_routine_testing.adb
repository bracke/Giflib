with Giflib_Tooling.Source_Limits;
with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Suite_Routine_Analysis;
with Giflib_Tooling.Work_Budgets;

package body Giflib_Tooling.Suite_Routine_Testing is
   function Registers_Test_Routine (Text : String) return Boolean is
      Budget : Giflib_Tooling.Work_Budgets.Budget;
      Parsed : constant Giflib_Tooling.Source_Model.Parsed_Source :=
        Giflib_Tooling.Source_Model.Parse
          (Text, Giflib_Tooling.Source_Limits.Default_Parsing_Limits, Budget);
   begin
      return Giflib_Tooling.Suite_Routine_Analysis.Registers_Test_Routine
        (Parsed, Budget);
   end Registers_Test_Routine;
end Giflib_Tooling.Suite_Routine_Testing;
