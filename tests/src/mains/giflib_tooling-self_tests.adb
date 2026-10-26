with Ada.Strings.Unbounded;

with Project_Tools.Files;
with Project_Tools.Processes;
with Project_Tools.Test_Fixtures;
with Project_Tools.Text;

with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Transitions;

package body Giflib_Tooling.Self_Tests is
   use Ada.Strings.Unbounded;
   package Source renames Giflib_Tooling.Source_Model;
   package Files renames Project_Tools.Files;
   package Processes renames Project_Tools.Processes;
   package Fixtures renames Project_Tools.Test_Fixtures;

   procedure Check (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Fail ("self-test failed: " & Message);
      end if;
   end Check;

   procedure Run is
      Fields : Source.Name_Vectors.Vector;
      Statement_Count : Natural := 0;
      procedure Count (Statement : Source.Token_Vectors.Vector) is
         pragma Unreferenced (Statement);
      begin
         Statement_Count := Statement_Count + 1;
      end Count;
      Parsed_Fields : constant Source.Name_Vectors.Vector :=
        Source.Record_Fields
          ("type Sample is record A : Natural; B : Boolean; end record;",
           "Sample");
   begin
      Fields.Append (To_Unbounded_String ("current_state"));
      Source.Scan_Statements ("X := ';'; Y := 1;", Count'Access);
      Check (Statement_Count = 2, "character literal statement scan");
      Check
        (not Source.Contains_Code
           ("-- with Project_Tools.Files;", "with Project_Tools."),
         "Ada comments are not code");
      Check
        (not Source.Has_GPR_With
           ("-- with ""dependency.gpr"";", "dependency.gpr"),
         "GPR comments do not satisfy imports");
      Check
        (not Source.Has_Config_Assignment
           ("# gnat_native = ""^15""", "gnat_native", """^15"""),
         "TOML comments do not satisfy assignments");
      Check
        (Source.Has_Config_Assignment
           ("gnat_native = ""^15"" # pinned", "gnat_native", """^15"""),
         "TOML assignment parsing");
      Check
        (Natural (Parsed_Fields.Length) = 2
         and then Source.Contains (Parsed_Fields, "a")
         and then Source.Contains (Parsed_Fields, "b"),
         "record field derivation");
      Check
        (Transitions.Violation
           (Source.Lex ("Object.Current_State := Ready"), Fields),
         "direct state assignment");
      Check
        (Transitions.Violation
           (Source.Lex ("Sneak (Object.Current_State)"), Fields),
         "unknown protected-field helper");
      Check
        (Transitions.Violation
           (Source.Lex ("Resource_Management.Release_And_Mutate (Object)"),
            Fields),
         "approved-call prefix collision");
      Check
        (not Transitions.Violation
           (Source.Lex ("Resource_Management.Release (Object)"), Fields),
         "exact approved call");
      Check
        (Transitions.Violation
           (Source.Lex ("Alias : Decoder renames Object"), Fields),
         "whole-session alias");
      Check
        (Transitions.Violation
           (Source.Lex ("Complete (Object)"), Fields, "unreviewed.adb"),
         "file-scoped local approval");
      Check
        (not Transitions.Violation
           (Source.Lex ("X := ';'; -- Object.Current_State := Failed"), Fields),
         "literal and comment isolation");
      declare
         Attributes : constant Source.Name_Vectors.Vector :=
           Source.GPR_Attribute_Strings
             ("Library_Interface := (""Decoy""); " &
              "for Library_Interface use (""Actual"");",
              "Library_Interface");
      begin
         Check
           (Natural (Attributes.Length) = 1
            and then To_String (Attributes.First_Element) = "Actual",
            "exact GPR attribute parsing");
      end;
   end Run;

   procedure Run_Mutations (Root : String; Probe : String) is
      LF : constant Character := ASCII.LF;
      Skip_Entries : constant Files.Name_List :=
        [To_Unbounded_String (".git"), To_Unbounded_String ("alire"),
         To_Unbounded_String ("obj"), To_Unbounded_String ("bin"),
         To_Unbounded_String ("lib"), To_Unbounded_String ("fixtures"),
         To_Unbounded_String ("artifacts")];
      No_Files : constant Files.Name_List := [1 .. 0 => <>];

      procedure Expect_Rejected
        (Name : String;
         Mutate : not null access procedure (Fixture : String);
         Expected : String)
      is
         Fixture : constant String := Fixtures.Fresh_Temp_Dir ("giflib-" & Name);
      begin
         Files.Copy_Filtered_Tree
           (Root, Fixture, Skip_Entries, No_Files, Quiet => True);
         Mutate (Fixture);
         declare
            Result : constant Processes.Captured_Process :=
              Processes.Capture_Command
                (Probe,
                 Processes.Arguments
                   ([Processes.Argument (Fixture)]),
                 Err_To_Out => True);
         begin
            Check
              (Result.Status /= 0
               and then Project_Tools.Text.Contains
                 (Source.Lower (To_String (Result.Output)),
                  Source.Lower (Expected)),
               "repository mutation was not rejected: " & Name);
         end;
         Fixtures.Cleanup (Fixture);
      exception
         when others =>
            Fixtures.Cleanup (Fixture);
            raise;
      end Expect_Rejected;

      procedure Add_Object_Alias (Fixture : String) is
      begin
         Fixtures.Write_Text_File
           (Files.Join (Fixture, "src/giflib-decoding-alias_mutation.adb"),
            "procedure Alias_Mutation (Object : in out Decoder) is" & LF &
            "   Alias : Decoder renames Object;" & LF &
            "begin" & LF &
            "   Alias.Current_State := Failed;" & LF &
            "end Alias_Mutation;" & LF);
      end Add_Object_Alias;

      procedure Add_Local_Helper (Fixture : String) is
      begin
         Fixtures.Write_Text_File
           (Files.Join (Fixture, "src/giflib-decoding-helper_mutation.adb"),
            "procedure Helper_Mutation (Object : in out Decoder) is" & LF &
            "begin" & LF &
            "   Complete (Object);" & LF &
            "end Helper_Mutation;" & LF);
      end Add_Local_Helper;

      procedure Add_Local_Ownership (Fixture : String) is
      begin
         Fixtures.Write_Text_File
           (Files.Join (Fixture, "src/giflib-internal-ownership_mutation.adb"),
            "procedure Ownership_Mutation is" & LF &
            "   package Extra is new Owned_Objects (Workspace);" & LF &
            "begin" & LF &
            "   null;" & LF &
            "end Ownership_Mutation;" & LF);
      end Add_Local_Ownership;

      procedure Add_Misplaced_Subunit (Fixture : String) is
      begin
         Fixtures.Write_Text_File
           (Files.Join (Fixture, "tests/src/misplaced/probe.adb"),
            "separate (Giflib.Testing)" & LF &
            "procedure Probe is" & LF &
            "begin" & LF &
            "   null;" & LF &
            "end Probe;" & LF);
      end Add_Misplaced_Subunit;

      procedure Add_Interface_Decoy (Fixture : String) is
      begin
         Fixtures.Write_Text_File
           (Files.Join (Fixture, "giflib.gpr"),
            "with ""giflib_build.gpr"";" & LF &
            "project Mutation is" & LF &
            "   Library_Interface := (""Giflib"");" & LF &
            "   for Library_Interface use (""Wrong.Unit"");" & LF &
            "end Mutation;" & LF);
      end Add_Interface_Decoy;

      procedure Add_Unchecked_Main (Fixture : String) is
      begin
         Fixtures.Write_Text_File
           (Files.Join (Fixture, "tests/tools.gpr"),
            "with ""../giflib.gpr"";" & LF &
            "project Tools is" & LF &
            "   for Main use (""unchecked_main.adb"");" & LF &
            "end Tools;" & LF);
         Fixtures.Write_Text_File
           (Files.Join (Fixture, "tests/src/mains/unchecked_main.adb"),
            "procedure Unchecked_Main is" & LF &
            "begin" & LF &
            "   null;" & LF &
            "end Unchecked_Main;" & LF);
      end Add_Unchecked_Main;
   begin
      Expect_Rejected
        ("object-alias", Add_Object_Alias'Access, "session state mutation");
      Expect_Rejected
        ("local-helper", Add_Local_Helper'Access, "session state mutation");
      Expect_Rejected
        ("local-ownership", Add_Local_Ownership'Access,
         "ownership-container instances");
      Expect_Rejected
        ("misplaced-subunit", Add_Misplaced_Subunit'Access,
         "subunit is outside tests/src/subunits");
      Expect_Rejected
        ("interface-decoy", Add_Interface_Decoy'Access,
         "library interface unit inventory");
      Expect_Rejected
        ("unchecked-main", Add_Unchecked_Main'Access,
         "does not import project_tools");
   end Run_Mutations;
end Giflib_Tooling.Self_Tests;
