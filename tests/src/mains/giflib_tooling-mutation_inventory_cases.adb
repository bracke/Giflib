with Project_Tools.Files;
with Project_Tools.Test_Fixtures;
with Giflib_Tooling.Mutation_Sources;

package body Giflib_Tooling.Mutation_Inventory_Cases is
   package Files renames Project_Tools.Files;
   package Fixtures renames Project_Tools.Test_Fixtures;
   package Sources renames Giflib_Tooling.Mutation_Sources;
   LF : constant Character := ASCII.LF;

   procedure Add_Unchecked_Main (Fixture : String) is
   begin
      Fixtures.Write_Text_File
        (Files.Join (Fixture, "tests/tools.gpr"),
         "with ""../giflib.gpr"";" & LF
         & "project Tools is" & LF
         & "   for Main use (""unchecked_main.adb"");" & LF
         & "end Tools;" & LF);
      Fixtures.Write_Text_File
        (Files.Join (Fixture, "tests/src/mains/unchecked_main.adb"),
         "procedure Unchecked_Main is" & LF
         & "begin" & LF
         & "   null;" & LF
         & "end Unchecked_Main;" & LF);
   end Add_Unchecked_Main;

   procedure Remove_Declared_Main (Fixture : String) is
   begin
      Sources.Replace_Text
        (Files.Join (Fixture, "tests/tools.gpr"),
         "      ""giflib_fuzz.adb"", ""giflib_check.adb"", "
         & """giflib_tooling_tests.adb""," & LF,
         "      ""giflib_check.adb"", ""giflib_tooling_tests.adb""," & LF);
   end Remove_Declared_Main;

   procedure Duplicate_Declared_Main (Fixture : String) is
   begin
      Sources.Replace_Text
        (Files.Join (Fixture, "tests/tools.gpr"),
         "      ""giflib_fuzz.adb"", ""giflib_check.adb"", "
         & """giflib_tooling_tests.adb""," & LF,
         "      ""giflib_fuzz.adb"", ""giflib_check.adb"", "
         & """giflib_check.adb"", ""giflib_tooling_tests.adb""," & LF);
   end Duplicate_Declared_Main;

   procedure Add_Stale_Documented_Executable (Fixture : String) is
   begin
      Sources.Replace_Text
        (Files.Join (Fixture, "docs/IMPLEMENTATION_PLAN.md"),
         "### Ada tooling inventory" & LF,
         "### Ada tooling inventory" & LF & LF
         & "- `stale_tool`" & LF);
   end Add_Stale_Documented_Executable;

   procedure Duplicate_Documented_Executable (Fixture : String) is
   begin
      Sources.Replace_Text
        (Files.Join (Fixture, "docs/IMPLEMENTATION_PLAN.md"),
         "- `giflib_check`" & LF,
         "- `giflib_check`" & LF & "- `giflib_check`" & LF);
   end Duplicate_Documented_Executable;

   procedure Change_Main_Declaration (Fixture : String) is
   begin
      Fixtures.Write_Text_File
        (Files.Join (Fixture, "tests/src/mains/giflib_fuzz.adb"),
         "with Project_Tools.Files;" & LF & LF
         & "package body Wrong_Fuzz_Package is" & LF
         & "   Dummy : constant String := Project_Tools.Files.Join "
         & "(""a"", ""b"");" & LF
         & "   pragma Unreferenced (Dummy);" & LF
         & "   procedure Giflib_Fuzz is" & LF
         & "   begin" & LF
         & "      null;" & LF
         & "   end Giflib_Fuzz;" & LF
         & "   pragma Unreferenced (Giflib_Fuzz);" & LF
         & "end Wrong_Fuzz_Package;" & LF);
      Fixtures.Write_Text_File
        (Files.Join
           (Fixture, "tests/src/mains/wrong_fuzz_package.ads"),
         "package Wrong_Fuzz_Package is" & LF
         & "   pragma Elaborate_Body;" & LF
         & "end Wrong_Fuzz_Package;" & LF);
      Fixtures.Write_Text_File
        (Files.Join (Fixture, "tests/mutation_main.gpr"),
         "with ""../giflib.gpr"";" & LF & LF
         & "project Mutation_Main extends ""tests_common.gpr"" is" & LF
         & "   for Source_Dirs use "
         & "(""src/mains"", ""src/tooling_subunits"");" & LF
         & "   for Object_Dir use ""obj/mutation-main"";" & LF
         & "   package Naming is" & LF
         & "      for Body (""Wrong_Fuzz_Package"") use "
         & """giflib_fuzz.adb"";" & LF
         & "   end Naming;" & LF
         & "end Mutation_Main;" & LF);
   end Change_Main_Declaration;
end Giflib_Tooling.Mutation_Inventory_Cases;
