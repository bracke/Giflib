with Ada.Strings.Unbounded;

with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Work_Budgets;

private package Giflib_Tooling.Suite_Registrations is
   type Registration_Issue is
     (No_Registration_Issue, Suite_Body_Missing, Suite_Return_Missing,
      Suite_Return_Ambiguous);
   type Registration_Inventory is record
      Units : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
      Duplicate : Ada.Strings.Unbounded.Unbounded_String;
      Issue : Registration_Issue := No_Registration_Issue;
   end record;

   function Registrations
     (Parsed : Giflib_Tooling.Source_Model.Parsed_Source;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget)
      return Registration_Inventory;
end Giflib_Tooling.Suite_Registrations;
