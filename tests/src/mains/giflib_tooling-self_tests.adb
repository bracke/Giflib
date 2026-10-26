with Ada.Strings.Unbounded;

with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Transitions;

package body Giflib_Tooling.Self_Tests is
   use Ada.Strings.Unbounded;
   package Source renames Giflib_Tooling.Source_Model;

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
        (not Transitions.Violation
           (Source.Lex ("X := ';'; -- Object.Current_State := Failed"), Fields),
         "literal and comment isolation");
   end Run;
end Giflib_Tooling.Self_Tests;
