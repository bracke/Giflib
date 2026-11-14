with Giflib_Tooling.Suite_Registrations;

private package Giflib_Tooling.Suite_Registration_Testing is
   subtype Registration_Issue is
     Giflib_Tooling.Suite_Registrations.Registration_Issue;
   Suite_Return_Ambiguous : constant Registration_Issue :=
     Giflib_Tooling.Suite_Registrations.Suite_Return_Ambiguous;
   subtype Registration_Inventory is
     Giflib_Tooling.Suite_Registrations.Registration_Inventory;

   function Registrations (Text : String) return Registration_Inventory;
end Giflib_Tooling.Suite_Registration_Testing;
