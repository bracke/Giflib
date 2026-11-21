with Ada.Strings.Unbounded;

with Giflib_Tooling.Configuration_Entries;
with Giflib_Tooling.Configuration_Source;
with Giflib_Tooling.Configuration_Quotes;
with Giflib_Tooling.Configuration_Testing;
with Giflib_Tooling.Dependency_Policy;
with Giflib_Tooling.Self_Test_Support;

package body Giflib_Tooling.Configuration_Tests is
   use Ada.Strings.Unbounded;
   package Check renames Giflib_Tooling.Self_Test_Support;
   package Config renames Giflib_Tooling.Configuration_Source;
   package Entries renames Giflib_Tooling.Configuration_Entries;
   package Quotes renames Giflib_Tooling.Configuration_Quotes;
   package Config_Testing renames Giflib_Tooling.Configuration_Testing;
   use type Entries.Entry_Kind;
   use type Config.Query_Result;

   function Has_Config_Assignment
     (Text : String;
      Key : String;
      Value : String;
      Section : String := "";
      Array_Section : Boolean := False) return Boolean is
     (Config.Find_Config_Assignment
        (Text, Key, Value, Section, Array_Section) = Config.Assignment_Found);

   function Has_Repository_Pin
     (Text : String;
      Crate : String;
      URL : String;
      Commit : String) return Boolean is
     (Config.Find_Repository_Pin
        (Text, Crate, URL, Commit) = Config.Assignment_Found);

   procedure Run is
      function Unterminated_Assignment_Is_Reported return Boolean is
         function Reported (Text : String) return Boolean is
            Found : Boolean := False;
            procedure Inspect
              (Item : Entries.Parsed_Entry; Stop : in out Boolean) is
            begin
               Found := Item.Kind = Entries.Malformed_Assignment_Entry;
               Stop := Found;
            end Inspect;
         begin
            Entries.Scan (Text, Inspect'Access);
            return Found;
         end Reported;
      begin
         return Reported ("values = [1, 2")
           and then Reported ("value = """"""unterminated");
      end Unterminated_Assignment_Is_Reported;

      function Nested_Table (Depth : Positive) return String is
         Result : Unbounded_String;
      begin
         for Level in 1 .. Depth loop
            pragma Unreferenced (Level);
            Append (Result, "{ value = ");
         end loop;
         Append (Result, """leaf""");
         for Level in 1 .. Depth loop
            pragma Unreferenced (Level);
            Append (Result, " }");
         end loop;
         return To_String (Result);
      end Nested_Table;

      Triple : constant String (1 .. 3) := [others => '"'];
      Four_Quotes : constant String (1 .. 4) := [others => '"'];
      Six_Quotes : constant String (1 .. 6) := [others => '"'];
      Extreme_Quote : constant String
        (Integer'Last .. Integer'Last) := [others => '"'];
      Project_Tools_URL : String renames
        Dependency_Policy.Project_Tools_URL;
      Project_Tools_Commit : String renames
        Dependency_Policy.Project_Tools_Commit;
      Multiline_Decoy : constant String :=
        "description = " & Triple & ASCII.LF &
        "[[depends-on]]" & ASCII.LF &
        "gnat_native = ""^15""" & ASCII.LF &
        Triple;
      Escaped_Multiline_Decoy : constant String :=
        "description = " & Triple & ASCII.LF &
        "\" & Triple & ASCII.LF &
        "[[depends-on]]" & ASCII.LF &
        "gnat_native = ""^15""" & ASCII.LF &
        Triple;
      Quoted_Multiline_Value : constant String :=
        Triple & "gif"" lib" & Triple;
      Compacted_Quoted_Multiline : constant String :=
        Triple & "gif""lib" & Triple;
      Quoted_Closing_Value : constant String :=
        Triple & "gif" & Four_Quotes;
      Malformed_Multiline_Decoy : constant String :=
        "description = " & Triple & "invalid" & Six_Quotes & ASCII.LF &
        "[[depends-on]]" & ASCII.LF &
        "gnat_native = ""^15""" & ASCII.LF & Triple;
   begin
      Check.Check
        (Unterminated_Assignment_Is_Reported,
         "unterminated configuration assignments are reported explicitly");
      Check.Check
        (Config.Find_Config_Assignment
           ("broken = [1" & ASCII.LF & "wanted = true",
            "wanted", "true") = Config.Malformed_Input,
         "configuration queries preserve malformed-input diagnostics");
      Check.Check
        (not Has_Config_Assignment
           ("# gnat_native = ""^15""", "gnat_native", """^15"""),
         "TOML comments do not satisfy assignments");
      Check.Check
        (Has_Config_Assignment
           ("gnat_native = ""^15"" # pinned", "gnat_native", """^15""")
         and then Has_Config_Assignment
           ("gnat_native = ""^15""" & ASCII.CR & ASCII.LF,
            "gnat_native", """^15"""),
         "TOML assignments accept comments and CRLF");
      Check.Check
        (not Has_Config_Assignment
           ("[unrelated]" & ASCII.LF & "gnat_native = ""^15""",
            "gnat_native", """^15""",
            Section => "depends-on", Array_Section => True)
         and then Has_Config_Assignment
           ("[[depends-on]]" & ASCII.LF & "gnat_native = ""^15""",
            "gnat_native", """^15""",
            Section => "depends-on", Array_Section => True),
         "TOML assignments are matched within their required section");
      Check.Check
        (not Has_Config_Assignment
           ("[[depends-on]" & ASCII.LF & "gnat_native = ""^15""",
            "gnat_native", """^15""",
            Section => "depends-on", Array_Section => True)
         and then not Has_Config_Assignment
           ("[]" & ASCII.LF & "gnat_native = ""^15""",
            "gnat_native", """^15"""),
         "malformed TOML headers cannot inherit or create section state");
      Check.Check
        (Has_Config_Assignment
           ("executables = [ ""giflib_tests"" ]",
            "executables", "[""giflib_tests""]"),
         "TOML value comparison ignores insignificant whitespace");
      Check.Check
        (Has_Config_Assignment
           ("executables = [" & ASCII.LF &
            "  ""giflib_tests""" & ASCII.LF & "]",
            "executables", "[""giflib_tests""]"),
         "TOML assignment parsing joins multiline arrays");
      Check.Check
        (Has_Config_Assignment
           ("executables = [" & ASCII.LF &
            "  " & Triple & "giflib_tests" & Triple & ASCII.LF & "]",
            "executables", "[""giflib_tests""]"),
         "TOML arrays retain same-line multiline string elements");
      Check.Check
        (Has_Config_Assignment
           ("executables = [" & ASCII.LF &
            "  " & Triple & "giflib_\" & ASCII.LF &
            "    tests" & Triple & ASCII.LF & "]",
            "executables", "[""giflib_tests""]"),
         "TOML arrays retain physically multiline string elements");
      Check.Check
        (not Has_Config_Assignment
           (Multiline_Decoy, "gnat_native", """^15""",
            Section => "depends-on", Array_Section => True),
         "TOML multiline strings cannot inject assignments or sections");
      Check.Check
        (not Has_Config_Assignment
           (Escaped_Multiline_Decoy, "gnat_native", """^15""",
            Section => "depends-on", Array_Section => True),
         "escaped triple quotes do not terminate multiline strings");
      Check.Check
        (not Has_Config_Assignment
           (Malformed_Multiline_Decoy, "gnat_native", """^15""",
            Section => "depends-on", Array_Section => True),
         "invalid multiline quote runs cannot expose configuration entries");
      Check.Check
        (not Has_Config_Assignment
           ("name = " & Quoted_Multiline_Value,
            "name", Compacted_Quoted_Multiline),
         "quotes inside multiline strings do not make whitespace insignificant");
      Check.Check
        (Has_Config_Assignment
           ("name = " & Quoted_Closing_Value & " # trailing comment",
            "name", Quoted_Closing_Value),
         "multiline strings retain quotes adjoining their closing delimiter");
      Check.Check
        (Quotes.Run_Length ("""value""", 0, '"') = 0
         and then Quotes.Run_Length
           (Extreme_Quote, Integer'Last, '"') = 1
         and then not Quotes.Triple_At ("""value""", 0)
         and then not Quotes.Triple_At ("""value""", Integer'Last, '"'),
         "quote helpers reject positions outside their input bounds");
      Check.Check
        (Has_Repository_Pin
           ("[[pins]]" & ASCII.LF &
            "project_tools={ optional=true, url='" & Project_Tools_URL &
            "', commit='" & Project_Tools_Commit & "' }",
            "project_tools", Project_Tools_URL, Project_Tools_Commit)
         and then not Has_Repository_Pin
           ("# [[pins]]" & ASCII.LF &
            "# project_tools = { url = '" & Project_Tools_URL &
            "', commit = '" & Project_Tools_Commit & "' }",
            "project_tools", Project_Tools_URL, Project_Tools_Commit),
         "repository pins require an active pins assignment");
      Check.Check
        (not Has_Repository_Pin
           ("[[pins]]" & ASCII.LF &
            "project_tools = { url = '" & Project_Tools_URL &
            "', meta = { commit = '" & Project_Tools_Commit & "' } }",
            "project_tools", Project_Tools_URL, Project_Tools_Commit),
         "repository pins require commit at the outer inline-table level");
      Check.Check
        (Has_Repository_Pin
           ("[[pins]]" & ASCII.LF &
            "project_tools = { meta = { url = ""decoy"" }, url = '" &
            Project_Tools_URL & "', commit = '" & Project_Tools_Commit & "' }",
            "project_tools", Project_Tools_URL, Project_Tools_Commit),
         "repository pins allow nested values beside outer pin fields");
      Check.Check
        (not Has_Repository_Pin
           ("[[pins]]" & ASCII.LF &
            "project_tools = { meta = [ x = 1 }, " &
            "url = '" & Project_Tools_URL & "', commit = '" &
            Project_Tools_Commit & "' }",
            "project_tools", Project_Tools_URL, Project_Tools_Commit),
         "repository pins reject mismatched inline delimiters");
      Check.Check
        (Has_Repository_Pin
           ("[[pins]]" & ASCII.LF &
            "project_tools = { meta = " &
            Nested_Table
              (Config_Testing.Maximum_Delimiter_Depth - 1) &
            ", url = '" & Project_Tools_URL & "', commit = '" &
            Project_Tools_Commit & "' }",
            "project_tools", Project_Tools_URL, Project_Tools_Commit),
         "repository pins accept delimiter nesting at the fixed limit");
      Check.Check
        (not Has_Repository_Pin
           ("[[pins]]" & ASCII.LF &
            "project_tools = { meta = " &
            Nested_Table (Config_Testing.Maximum_Delimiter_Depth) &
            ", url = '" & Project_Tools_URL & "', commit = '" &
            Project_Tools_Commit & "' }",
            "project_tools", Project_Tools_URL, Project_Tools_Commit),
         "repository pins reject delimiter nesting above the fixed limit");
   end Run;
end Giflib_Tooling.Configuration_Tests;
