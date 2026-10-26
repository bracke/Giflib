with Ada.Strings.Unbounded;

with Project_Tools.Alire_Manifests;
with Project_Tools.Files;
with Project_Tools.Processes;
with Project_Tools.Text;

with Giflib_Tooling.Source_Model;

package body Giflib_Tooling.Boundaries is
   use Ada.Strings.Unbounded;
   package Files renames Project_Tools.Files;
   package Processes renames Project_Tools.Processes;
   package Source renames Giflib_Tooling.Source_Model;

   procedure Require_GPR_With
     (Root : String; Path : String; Dependency : String)
   is
   begin
      if not Source.Has_GPR_With
        (Files.Read_Raw_File (Files.Join (Root, Path)), Dependency)
      then
         Fail (Path & " does not import " & Dependency);
      end if;
   end Require_GPR_With;

   procedure Require_Config
     (Root : String; Path : String; Key : String; Value : String)
   is
   begin
      if not Source.Has_Config_Assignment
        (Files.Read_Raw_File (Files.Join (Root, Path)), Key, Value)
      then
         Fail (Path & " is missing exact assignment for " & Key);
      end if;
   end Require_Config;

   procedure Require_Project_Tools_With (Root : String; Path : String) is
   begin
      if not Source.Contains_Code
        (Files.Read_Raw_File (Files.Join (Root, Path)), "with Project_Tools.")
      then
         Fail (Path & " does not import Project_Tools in Ada code");
      end if;
   end Require_Project_Tools_With;

   procedure Check_API_Boundaries (Root : String) is
      Gprbuild : constant String := Processes.Locate_Command ("gprbuild");

      procedure Require_Rejected
        (Project : String; Expected : String; Failure : String)
      is
         Result : constant Processes.Captured_Process :=
           Processes.Capture_Command
             (Gprbuild,
              Processes.Arguments
                ([Processes.Argument ("-q"), Processes.Argument ("-p"),
                  Processes.Argument ("-P"),
                  Processes.Argument (Files.Join (Root, Project))]),
              Err_To_Out => True);
      begin
         if Result.Status = 0 then
            Fail (Failure & " unexpectedly compiled");
         elsif not Project_Tools.Text.Contains
           (Source.Lower (To_String (Result.Output)), Source.Lower (Expected))
         then
            Fail (Failure & " failed for an unexpected reason");
         end if;
      end Require_Rejected;
   begin
      Processes.Require_Command
        ("gprbuild", "giflib tooling: gprbuild is required", Quiet => True);
      Processes.Run
        ("public API compile", Root, Gprbuild,
         Processes.Arguments
           ([Processes.Argument ("-q"), Processes.Argument ("-p"),
             Processes.Argument ("-P"),
             Processes.Argument (Files.Join (Root, "tests/public_api.gpr"))]),
         Quiet => True);
      Require_Rejected
        ("tests/private_api_rejection.gpr", "private child unit",
         "private API probe");
      Require_Rejected
        ("tests/ownership_safety_rejection.gpr",
         "aspect ""no_controlled_parts"" applied to controlled type",
         "ownership safety probe");
   end Check_API_Boundaries;

   procedure Require_Project_Tools_Mains
     (Root : String; Project_Path : String; Source_Dir : String)
   is
      Mains : constant Source.Name_Vectors.Vector :=
        Source.GPR_Attribute_Strings
          (Files.Read_Raw_File (Files.Join (Root, Project_Path)), "Main");
   begin
      if Mains.Is_Empty then
         Fail (Project_Path & " has no exact Main attribute");
      end if;
      for Name of Mains loop
         Require_Project_Tools_With
           (Root, Files.Join (Source_Dir, To_String (Name)));
      end loop;
   end Require_Project_Tools_Mains;

   procedure Validate_Static (Root : String) is
   begin
      Require_Config (Root, "alire.toml", "gnat_native", """^15""");
      Require_Config (Root, "tests/alire.toml", "gnat_native", """^15""");
      Require_Config
        (Root, "tests/alire.toml", "executables", "[""giflib_tests""]");
      Require_Config
        (Root, "tests/alire.toml", "project-files", "[""unit_tests.gpr""]");
      Require_GPR_With (Root, "giflib.gpr", "giflib_build.gpr");
      Require_GPR_With
        (Root, "tests/giflib_whitebox.gpr", "../giflib_build.gpr");
      Require_GPR_With (Root, "tests/public_api.gpr", "../giflib.gpr");
      Require_GPR_With
        (Root, "tests/unit_tests.gpr", "giflib_whitebox.gpr");
      Require_GPR_With (Root, "tests/tools.gpr", "../giflib.gpr");
      Project_Tools.Alire_Manifests.Require_Workspace_Pin
        (Files.Join (Root, "tests/alire.toml"), "project_tools",
         "../../project_tools", Quiet => True);
      Require_Project_Tools_Mains
        (Root, "tests/unit_tests.gpr", "tests/src/test_mains");
      Require_Project_Tools_Mains
        (Root, "tests/tools.gpr", "tests/src/mains");
   end Validate_Static;

   procedure Validate_API (Root : String) is
   begin
      Check_API_Boundaries (Root);
   end Validate_API;

end Giflib_Tooling.Boundaries;
