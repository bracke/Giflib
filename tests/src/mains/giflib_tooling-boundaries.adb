with Giflib_Tooling.Name_Collections;
with Ada.Strings.Unbounded;

with Project_Tools.Files;
with Project_Tools.Processes;
with Project_Tools.Text;

with Giflib_Tooling.Configuration_Source;
with Giflib_Tooling.GPR_Analysis;
with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Token_Patterns;
with Giflib_Tooling.Text_Case;

package body Giflib_Tooling.Boundaries is
   use Ada.Strings.Unbounded;
   package Files renames Project_Tools.Files;
   package Processes renames Project_Tools.Processes;
   package Config renames Giflib_Tooling.Configuration_Source;
   package GPR renames Giflib_Tooling.GPR_Analysis;
   package Patterns renames Giflib_Tooling.Token_Patterns;
   package Snapshots renames Giflib_Tooling.Repository_Snapshots;
   package Text_Case renames Giflib_Tooling.Text_Case;
   use type Config.Query_Result;

   procedure Require_GPR_With
     (Repository : Snapshots.Snapshot;
      Path : String;
      Dependency : String;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget)
   is
      Found : Boolean := False;
      procedure Inspect (Text : String) is
      begin
         Giflib_Tooling.Work_Budgets.Charge_Scan (Budget, Text'Length);
         Found := GPR.Has_With (Text, Dependency);
      end Inspect;
   begin
      Snapshots.Inspect_Text (Repository, Path, Inspect'Access);
      if not Found then
         Fail (Path & " does not import " & Dependency);
      end if;
   end Require_GPR_With;

   procedure Require_Config
     (Repository : Snapshots.Snapshot;
      Path : String;
      Key : String;
      Value : String;
      Section : String := "";
      Array_Section : Boolean := False;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget)
   is
      Result : Config.Query_Result;
      procedure Inspect (Text : String) is
      begin
         Giflib_Tooling.Work_Budgets.Charge_Scan (Budget, Text'Length);
         Result := Config.Find_Config_Assignment
           (Text, Key, Value, Section, Array_Section);
      end Inspect;
   begin
      Snapshots.Inspect_Text (Repository, Path, Inspect'Access);
      case Result is
         when Config.Assignment_Found =>
            null;
         when Config.Assignment_Absent =>
            Fail (Path & " is missing exact assignment for " & Key);
         when Config.Malformed_Input =>
            Fail (Path & " contains malformed configuration syntax");
      end case;
   end Require_Config;

   procedure Require_Project_Tools_With
     (Cached_Sources : Giflib_Tooling.Repository_Source_Cache.Cache;
      Path : String;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget) is
      Found : Boolean := False;
      procedure Inspect (Parsed : Giflib_Tooling.Source_Model.Parsed_Source) is
      begin
         Found := Patterns.Contains_Code (Parsed, "with Project_Tools.");
      end Inspect;
   begin
      Giflib_Tooling.Work_Budgets.Charge_Scan
        (Budget,
         Giflib_Tooling.Repository_Source_Cache.Source_Length
           (Cached_Sources, Path));
      Giflib_Tooling.Repository_Source_Cache.Inspect
        (Cached_Sources, Path, Inspect'Access);
      if not Found then
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
           (Text_Case.Lower (To_String (Result.Output)),
            Text_Case.Lower (Expected))
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
     (Repository : Snapshots.Snapshot;
      Cached_Sources : Giflib_Tooling.Repository_Source_Cache.Cache;
      Project_Path : String;
      Source_Dir : String;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget)
   is
      Mains : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
      procedure Inspect (Text : String) is
      begin
         Giflib_Tooling.Work_Budgets.Charge_Scan (Budget, Text'Length);
         Mains := GPR.Attribute_Strings (Text, "Main");
      end Inspect;
   begin
      Snapshots.Inspect_Text (Repository, Project_Path, Inspect'Access);
      if Mains.Is_Empty then
         Fail (Project_Path & " has no exact Main attribute");
      end if;
      for Name of Mains loop
         Require_Project_Tools_With
           (Cached_Sources, Files.Join (Source_Dir, To_String (Name)), Budget);
      end loop;
   end Require_Project_Tools_Mains;

   procedure Validate_Static
     (Repository : Snapshots.Snapshot;
      Cached_Sources : Giflib_Tooling.Repository_Source_Cache.Cache;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget) is
      Pin : Config.Query_Result;
      procedure Inspect_Pin (Text : String) is
      begin
         Giflib_Tooling.Work_Budgets.Charge_Scan (Budget, Text'Length);
         Pin := Config.Find_Workspace_Pin
           (Text, "project_tools", "../../project_tools");
      end Inspect_Pin;
   begin
      Require_Config
        (Repository, "alire.toml", "gnat_native", """^15""",
         Section => "depends-on", Array_Section => True, Budget => Budget);
      Require_Config
        (Repository, "tests/alire.toml", "gnat_native", """^15""",
         Section => "depends-on", Array_Section => True, Budget => Budget);
      Require_Config
        (Repository, "tests/alire.toml", "executables", "[""giflib_tests""]",
         Budget => Budget);
      Require_Config
        (Repository, "tests/alire.toml", "project-files", "[""unit_tests.gpr""]",
         Budget => Budget);
      Require_GPR_With
        (Repository, "giflib.gpr", "giflib_build.gpr", Budget);
      Require_GPR_With
        (Repository, "tests/giflib_whitebox.gpr", "../giflib_build.gpr",
         Budget);
      Require_GPR_With
        (Repository, "tests/public_api.gpr", "../giflib.gpr", Budget);
      Require_GPR_With
        (Repository, "tests/unit_tests.gpr", "giflib_whitebox.gpr", Budget);
      Require_GPR_With
        (Repository, "tests/tools.gpr", "../giflib.gpr", Budget);
      Snapshots.Inspect_Text
        (Repository, "tests/alire.toml", Inspect_Pin'Access);
      case Pin is
         when Config.Assignment_Found =>
            null;
         when Config.Assignment_Absent =>
            Fail
              ("tests/alire.toml is missing the project_tools workspace pin");
         when Config.Malformed_Input =>
            Fail ("tests/alire.toml contains malformed configuration syntax");
      end case;
      Require_Project_Tools_Mains
        (Repository, Cached_Sources, "tests/unit_tests.gpr",
         "tests/src/test_mains", Budget);
      Require_Project_Tools_Mains
        (Repository, Cached_Sources, "tests/tools.gpr", "tests/src/mains",
         Budget);
   end Validate_Static;

   procedure Validate_API (Root : String) is
   begin
      Check_API_Boundaries (Root);
   end Validate_API;

end Giflib_Tooling.Boundaries;
