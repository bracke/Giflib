with Project_Tools.Files;
with Giflib_Tooling.Mutation_Sources;

package body Giflib_Tooling.Mutation_Suite_Cases is
   package Files renames Project_Tools.Files;
   package Sources renames Giflib_Tooling.Mutation_Sources;
   LF : constant Character := ASCII.LF;

   function Suite_Path (Fixture : String) return String is
     (Files.Join (Fixture, "tests/src/giflib-testing-suite.adb"));

   procedure Remove_Suite_Registration (Fixture : String) is
   begin
      Sources.Replace_Text
        (Suite_Path (Fixture),
         "      Suite.Add_Test (Primary_Decoder);" & LF,
         "");
   end Remove_Suite_Registration;

   procedure Redirect_Suite_Registration (Fixture : String) is
   begin
      Sources.Replace_Text
        (Suite_Path (Fixture),
         "      Suite : constant AUnit.Test_Suites.Access_Test_Suite := "
         & "AUnit.Test_Suites.New_Suite;" & LF,
         "      Suite : constant AUnit.Test_Suites.Access_Test_Suite := "
         & "AUnit.Test_Suites.New_Suite;" & LF
         & "      Other_Suite : constant "
         & "AUnit.Test_Suites.Access_Test_Suite := "
         & "AUnit.Test_Suites.New_Suite;" & LF);
      Sources.Replace_Text
        (Suite_Path (Fixture),
         "      Suite.Add_Test (Primary_Decoder);" & LF,
         "      Other_Suite.Add_Test (Primary_Decoder);" & LF);
   end Redirect_Suite_Registration;

   procedure Duplicate_Suite_Registration (Fixture : String) is
      Registration : constant String :=
        "      Suite.Add_Test (Primary_Decoder);" & LF;
   begin
      Sources.Replace_Text
        (Suite_Path (Fixture),
         Registration, Registration & Registration);
   end Duplicate_Suite_Registration;

   procedure Add_Unknown_Suite_Registration (Fixture : String) is
      Registration : constant String :=
        "      Suite.Add_Test (Primary_Decoder);" & LF;
   begin
      Sources.Replace_Text
        (Suite_Path (Fixture),
         Registration,
         Registration
         & "      Suite.Add_Test "
         & "(new Giflib.Testing.Unknown.Test);" & LF);
   end Add_Unknown_Suite_Registration;
end Giflib_Tooling.Mutation_Suite_Cases;
