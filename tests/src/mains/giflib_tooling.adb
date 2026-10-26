with Project_Tools.AUnit_Checks;
with Project_Tools.Files;
with Project_Tools.Release_Checks;

with Giflib_Tooling.Architecture;
with Giflib_Tooling.Boundaries;
with Giflib_Tooling.Transitions;

package body Giflib_Tooling is
   package Files renames Project_Tools.Files;

   procedure Fail (Message : String) is
   begin
      Project_Tools.Release_Checks.Fail ("giflib tooling: " & Message);
   end Fail;

   procedure Validate (Root : String) is
   begin
      Boundaries.Validate (Root);
      Architecture.Validate (Root);
      Transitions.Validate (Root);
      Project_Tools.Release_Checks.Require_GPR_Main_Inventory
        (Project_File => Files.Join (Root, "tests/unit_tests.gpr"),
         Documentation_File => Files.Join (Root, "docs/IMPLEMENTATION_PLAN.md"),
         Source_Directory => Files.Join (Root, "tests/src/test_mains"),
         Quiet => True);
      Project_Tools.Release_Checks.Require_GPR_Main_Inventory
        (Project_File => Files.Join (Root, "tests/tools.gpr"),
         Documentation_File => Files.Join (Root, "docs/IMPLEMENTATION_PLAN.md"),
         Source_Directory => Files.Join (Root, "tests/src/mains"),
         Quiet => True);
      Project_Tools.AUnit_Checks.Require_Registered_Test_Packages
        (Test_Dir => Files.Join (Root, "tests/src"),
         Spec_Pattern => "giflib-testing-test_*.ads",
         Suite_Path => Files.Join (Root, "tests/src/giflib-testing-suite.adb"),
         Suite_Add_Prefix => "new ", Suite_Add_Suffix => ".Test",
         Required_Stem_Suffix => "", Quiet => True);
   exception
      when Program_Error =>
         raise;
      when others =>
         Fail ("validation raised an unexpected exception");
   end Validate;
end Giflib_Tooling;
