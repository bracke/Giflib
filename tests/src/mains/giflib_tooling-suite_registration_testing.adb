with Giflib_Tooling.Source_Limits;
with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Work_Budgets;

package body Giflib_Tooling.Suite_Registration_Testing is
   function Registrations (Text : String) return Registration_Inventory is
      Budget : Giflib_Tooling.Work_Budgets.Budget;
      Parsed : constant Giflib_Tooling.Source_Model.Parsed_Source :=
        Giflib_Tooling.Source_Model.Parse
          (Text, Giflib_Tooling.Source_Limits.Default_Parsing_Limits, Budget);
   begin
      return Giflib_Tooling.Suite_Registrations.Registrations (Parsed, Budget);
   end Registrations;
end Giflib_Tooling.Suite_Registration_Testing;
