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
      Sessions : Source.Name_Vectors.Vector;
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
      Sessions.Append (To_Unbounded_String ("object"));
      Sessions.Append (To_Unbounded_String ("session"));
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
           (Source.Lex ("Object.Current_State := Ready"), Fields, Sessions),
         "direct state assignment");
      Check
        (Transitions.Violation
           (Source.Lex ("Sneak (Object.Current_State)"), Fields, Sessions),
         "unknown protected-field helper");
      Check
        (Transitions.Violation
           (Source.Lex ("Sneak ((Object.Current_State))"), Fields, Sessions),
         "grouped protected-field helper");
      Check
        (Transitions.Violation
           (Source.Lex ("Session.Current_State := Ready"), Fields, Sessions),
         "differently named session assignment");
      Check
        (Transitions.Violation
           (Source.Lex ("Resource_Management.Release_And_Mutate (Object)"),
            Fields, Sessions),
         "approved-call prefix collision");
      Check
        (not Transitions.Violation
           (Source.Lex ("Resource_Management.Release (Object)"), Fields,
            Sessions),
         "exact approved call");
      Check
        (Transitions.Violation
           (Source.Lex ("Alias : Decoder renames Object"), Fields, Sessions),
         "whole-session alias");
      Check
        (Transitions.Violation
           (Source.Lex ("Complete (Object)"), Fields, Sessions,
            "unreviewed.adb"),
         "file-scoped local approval");
      Check
        (not Transitions.Violation
           (Source.Lex ("X := ';'; -- Object.Current_State := Failed"), Fields,
            Sessions),
         "literal and comment isolation");
      Check
        (Source.Contains
           (Source.Session_Identifiers
              ("procedure P (First, Session : in out Decoder) is", "Decoder"),
            "session"),
         "session identifier derivation");
      Check
        (Source.Contains
           (Source.Session_Identifiers
              ("procedure P (First, Session : in out Decoder) is", "Decoder"),
            "first"),
         "grouped session identifier derivation");
      Check
        (Source.Has_Nested_Program_Unit
           ("procedure Outer is " &
            "procedure Complete is begin null; end Complete; " &
            "begin null; end Outer;"),
         "nested declaration detection");
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
      Gprbuild : constant String := Processes.Locate_Command ("gprbuild");
      Skip_Entries : constant Files.Name_List :=
        [To_Unbounded_String (".git"), To_Unbounded_String ("alire"),
         To_Unbounded_String ("obj"), To_Unbounded_String ("bin"),
         To_Unbounded_String ("lib"), To_Unbounded_String ("fixtures"),
         To_Unbounded_String ("artifacts")];
      No_Files : constant Files.Name_List := [1 .. 0 => <>];

      procedure Replace_Text
        (Path : String; Before : String; After : String)
      is
         Content : constant String := Files.Read_Raw_File (Path);
         Position : constant Natural :=
           Project_Tools.Text.Index (Content, Before);
      begin
         Check (Position > 0, "mutation anchor is missing: " & Path);
         Fixtures.Write_Text_File
           (Path,
            Content (Content'First .. Position - 1) & After &
            Content (Position + Before'Length .. Content'Last));
      end Replace_Text;

      procedure Expect_Rejected
        (Name : String;
         Mutate : not null access procedure (Fixture : String);
         Expected : String;
         Compile_First : Boolean := False)
      is
         Fixture : constant String := Fixtures.Fresh_Temp_Dir ("giflib-" & Name);
      begin
         Files.Copy_Filtered_Tree
           (Root, Fixture, Skip_Entries, No_Files, Quiet => True);
         Mutate (Fixture);
         if Compile_First then
            Check
              (Processes.Run_Status
                 ("compile " & Name & " mutation", Fixture, Gprbuild,
                  Processes.Arguments
                    ([Processes.Argument ("-q"), Processes.Argument ("-p"),
                      Processes.Argument ("-P"),
                      Processes.Argument (Files.Join (Fixture, "giflib.gpr"))]),
                  Quiet => True) = 0,
               "repository mutation does not compile: " & Name);
         end if;
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
               "repository mutation was not rejected: " & Name & ": " &
               To_String (Result.Output));
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
           (Files.Join (Fixture, "src/giflib-decoding-reset.adb"),
            "separate (Giflib.Decoding)" & LF &
            "function Reset" & LF &
            "  (Object : in out Decoder;" & LF &
            "   Options : Decode_Options := Default_Options;" & LF &
            "   Constraints : Limits.Limit_Set := Limits.Default_Limits)" & LF &
            "   return Results.Result" & LF &
            "is" & LF &
            "   Alias : Decoder renames Object;" & LF &
            "begin" & LF &
            "   Alias.Current_State := Initialized;" & LF &
            "   return Initialize (Alias, Options, Constraints);" & LF &
            "end Reset;" & LF);
      end Add_Object_Alias;

      procedure Add_Local_Helper (Fixture : String) is
      begin
         Fixtures.Write_Text_File
           (Files.Join (Fixture, "src/giflib-decoding-reset.adb"),
            "separate (Giflib.Decoding)" & LF &
            "function Reset" & LF &
            "  (Object : in out Decoder;" & LF &
            "   Options : Decode_Options := Default_Options;" & LF &
            "   Constraints : Limits.Limit_Set := Limits.Default_Limits)" & LF &
            "   return Results.Result" & LF &
            "is" & LF &
            "   package Session_Transitions is" & LF &
            "      procedure Reset_Session (Target : in out Decoder);" & LF &
            "   end Session_Transitions;" & LF &
            "   package body Session_Transitions is" & LF &
            "      procedure Reset_Session (Target : in out Decoder) is" & LF &
            "      begin" & LF &
            "         Target.Current_State := Initialized;" & LF &
            "      end Reset_Session;" & LF &
            "   end Session_Transitions;" & LF &
            "begin" & LF &
            "   Session_Transitions.Reset_Session (Object);" & LF &
            "   return Initialize (Object, Options, Constraints);" & LF &
            "end Reset;" & LF);
      end Add_Local_Helper;

      procedure Add_Alternate_Session_Name (Fixture : String) is
         Path : constant String :=
           Files.Join (Fixture, "src/giflib-decoding.adb");
      begin
         Replace_Text
           (Path,
            "package body Giflib.Decoding is" & LF,
            "package body Giflib.Decoding is" & LF &
            "   procedure Alternate_Name_Mutation" & LF &
            "     (Session : in out Decoder)" & LF &
            "   is" & LF &
            "   begin" & LF &
            "      Session.Current_State := Initialized;" & LF &
            "   end Alternate_Name_Mutation;" & LF &
            "   pragma Unreferenced (Alternate_Name_Mutation);" & LF);
      end Add_Alternate_Session_Name;

      procedure Add_Local_Ownership (Fixture : String) is
      begin
         Replace_Text
           (Files.Join (Fixture, "src/giflib-internal-lzw.ads"),
            "   package Workspace_Ownership is new Owned_Objects" & LF &
            "     (Workspace);",
            "   package Workspace_Ownership is new Owned_Objects" & LF &
            "     (Workspace);" & LF &
            "   package Extra_Workspace_Ownership is new Owned_Objects" & LF &
            "     (Workspace);");
      end Add_Local_Ownership;

      procedure Add_API_Boundary_Bypass (Fixture : String) is
      begin
         Fixtures.Write_Text_File
           (Files.Join
              (Fixture,
               "tests/private_api/giflib_internal_import_must_fail.adb"),
            "with Giflib;" & LF & LF &
            "procedure Giflib_Internal_Import_Must_Fail is" & LF &
            "begin" & LF &
            "   null;" & LF &
            "end Giflib_Internal_Import_Must_Fail;" & LF);
      end Add_API_Boundary_Bypass;

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
        ("object-alias", Add_Object_Alias'Access, "session state mutation",
         Compile_First => True);
      Expect_Rejected
        ("local-helper", Add_Local_Helper'Access, "nested declaration",
         Compile_First => True);
      Expect_Rejected
        ("alternate-session-name", Add_Alternate_Session_Name'Access,
         "session state mutation", Compile_First => True);
      Expect_Rejected
        ("local-ownership", Add_Local_Ownership'Access,
         "ownership-container instances", Compile_First => True);
      Expect_Rejected
        ("misplaced-subunit", Add_Misplaced_Subunit'Access,
         "subunit is outside tests/src/subunits");
      Expect_Rejected
        ("interface-decoy", Add_Interface_Decoy'Access,
         "library interface unit inventory");
      Expect_Rejected
        ("unchecked-main", Add_Unchecked_Main'Access,
         "does not import project_tools");
      Expect_Rejected
        ("api-boundary", Add_API_Boundary_Bypass'Access,
         "private API probe unexpectedly compiled");
   end Run_Mutations;
end Giflib_Tooling.Self_Tests;
