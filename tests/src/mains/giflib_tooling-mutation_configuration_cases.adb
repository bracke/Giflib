with Project_Tools.Files;
with Project_Tools.Test_Fixtures;
with Giflib_Tooling.Dependency_Policy;
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

   procedure Change_Repository_Pin (Fixture : String) is
   begin
      Sources.Replace_Text
        (Files.Join (Fixture, "tests/alire.toml"),
         "commit = """ & Dependency_Policy.Project_Tools_Commit & """",
         "commit = ""0000000000000000000000000000000000000000""");
   end Change_Repository_Pin;
end Giflib_Tooling.Mutation_Configuration_Cases;
