with Project_Tools.Files;
with Project_Tools.Test_Fixtures;
with Giflib_Tooling.Mutation_Sources;

package body Giflib_Tooling.Mutation_Configuration_Cases is
   package Files renames Project_Tools.Files;
   package Fixtures renames Project_Tools.Test_Fixtures;
   package Sources renames Giflib_Tooling.Mutation_Sources;
   LF : constant Character := ASCII.LF;

   procedure Add_Interface_Decoy (Fixture : String) is
   begin
      Fixtures.Write_Text_File
        (Files.Join (Fixture, "giflib.gpr"),
         "with ""giflib_build.gpr"";" & LF
         & "project Mutation is" & LF
         & "   Library_Interface := (""Giflib"");" & LF
         & "   for Library_Interface use (""Wrong.Unit"");" & LF
         & "end Mutation;" & LF);
   end Add_Interface_Decoy;

   procedure Change_Workspace_Pin (Fixture : String) is
   begin
      Sources.Replace_Text
        (Files.Join (Fixture, "tests/alire.toml"),
         "project_tools = { path = ""../../project_tools"" }",
         "project_tools = { path = ""../wrong"" }");
   end Change_Workspace_Pin;
end Giflib_Tooling.Mutation_Configuration_Cases;
