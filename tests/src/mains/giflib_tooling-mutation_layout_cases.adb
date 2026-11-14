with Ada.Strings.Unbounded;
with Project_Tools.Files;
with Project_Tools.Test_Fixtures;

package body Giflib_Tooling.Mutation_Layout_Cases is
   use Ada.Strings.Unbounded;
   package Files renames Project_Tools.Files;
   package Fixtures renames Project_Tools.Test_Fixtures;
   LF : constant Character := ASCII.LF;

   procedure Add_Duplicate_Source_Basename (Fixture : String) is
   begin
      Fixtures.Write_Text_File
        (Files.Join (Fixture, "src/duplicate/giflib.ads"),
         "package Giflib is end Giflib;" & LF);
   end Add_Duplicate_Source_Basename;

   procedure Add_API_Boundary_Bypass (Fixture : String) is
   begin
      Fixtures.Write_Text_File
        (Files.Join
           (Fixture,
            "tests/private_api/giflib_internal_import_must_fail.adb"),
         "with Giflib;" & LF & LF
         & "procedure Giflib_Internal_Import_Must_Fail is" & LF
         & "begin" & LF
         & "   null;" & LF
         & "end Giflib_Internal_Import_Must_Fail;" & LF);
   end Add_API_Boundary_Bypass;

   procedure Add_Misplaced_Subunit (Fixture : String) is
   begin
      Fixtures.Write_Text_File
        (Files.Join (Fixture, "tests/src/misplaced/probe.adb"),
         "separate (Giflib.Testing)" & LF
         & "procedure Probe is" & LF
         & "begin" & LF
         & "   null;" & LF
         & "end Probe;" & LF);
   end Add_Misplaced_Subunit;

   procedure Add_Misplaced_Test_Body (Fixture : String) is
   begin
      Fixtures.Write_Text_File
        (Files.Join (Fixture, "tests/src/misplaced/helper.adb"),
         "procedure Helper is begin null; end Helper;" & LF);
   end Add_Misplaced_Test_Body;

   procedure Add_Invalid_Test_Subunit (Fixture : String) is
   begin
      Fixtures.Write_Text_File
        (Files.Join
           (Fixture, "tests/src/subunits/giflib-testing-invalid_probe.adb"),
         "package body Giflib.Testing.Invalid_Probe is" & LF
         & "end Giflib.Testing.Invalid_Probe;" & LF);
   end Add_Invalid_Test_Subunit;

   procedure Add_Invalid_Tooling_Subunit (Fixture : String) is
   begin
      Fixtures.Write_Text_File
        (Files.Join
           (Fixture,
            "tests/src/tooling_subunits/giflib_tooling-invalid_probe.ads"),
         "package Giflib_Tooling.Invalid_Probe is" & LF
         & "end Giflib_Tooling.Invalid_Probe;" & LF);
   end Add_Invalid_Tooling_Subunit;

   procedure Add_Oversized_Tooling_Main (Fixture : String) is
      Value : Unbounded_String;
   begin
      for Line in 1 .. 501 loop
         pragma Unreferenced (Line);
         Append (Value, "--  tooling size mutation" & LF);
      end loop;
      Fixtures.Write_Text_File
        (Files.Join (Fixture, "tests/src/mains/oversized_tool.adb"),
         To_String (Value));
   end Add_Oversized_Tooling_Main;
end Giflib_Tooling.Mutation_Layout_Cases;
