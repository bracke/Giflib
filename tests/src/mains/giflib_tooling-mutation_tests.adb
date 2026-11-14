with Ada.Strings.Unbounded;

with Project_Tools.Files;
with Project_Tools.Processes;
with Project_Tools.Test_Fixtures;
with Project_Tools.Text;

with Giflib_Tooling.Mutation_Cases;
with Giflib_Tooling.Text_Case;

package body Giflib_Tooling.Mutation_Tests is
   use Ada.Strings.Unbounded;
   package Cases renames Giflib_Tooling.Mutation_Cases;
   package Files renames Project_Tools.Files;
   package Fixtures renames Project_Tools.Test_Fixtures;
   package Processes renames Project_Tools.Processes;
   package Text_Case renames Giflib_Tooling.Text_Case;

   procedure Check (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Fail ("mutation test failed: " & Message);
      end if;
   end Check;

   procedure Run (Root : String; Probe : String) is
      Gprbuild : constant String := Processes.Locate_Command ("gprbuild");
      Skip_Entries : constant Files.Name_List :=
        [To_Unbounded_String (".git"), To_Unbounded_String ("alire"),
         To_Unbounded_String ("obj"), To_Unbounded_String ("bin"),
         To_Unbounded_String ("lib"), To_Unbounded_String ("fixtures"),
         To_Unbounded_String ("artifacts")];
      No_Files : constant Files.Name_List := [1 .. 0 => <>];

      procedure Expect_Rejected
        (Item : Cases.Mutation_Case)
      is
         Name : constant String := To_String (Item.Name);
         Expected : constant String := To_String (Item.Expected);
         Compile_Project : constant String :=
           To_String (Item.Compile_Project);
         Fixture : constant String := Fixtures.Fresh_Temp_Dir ("giflib-" & Name);
      begin
         Files.Copy_Filtered_Tree
           (Root, Fixture, Skip_Entries, No_Files, Quiet => True);
         Cases.Apply (Item, Fixture);
         if Compile_Project /= "" then
            Check
              (Processes.Run_Status
                 ("compile " & Name & " mutation", Fixture, Gprbuild,
                  Processes.Arguments
                    ([Processes.Argument ("-q"), Processes.Argument ("-p"),
                      Processes.Argument ("-P"),
                      Processes.Argument
                        (Files.Join (Fixture, Compile_Project))]),
                  Quiet => True) = 0,
               "repository mutation does not compile: " & Name);
         end if;
         declare
            Result : constant Processes.Captured_Process :=
              Processes.Capture_Command
                (Probe, Processes.Arguments ([Processes.Argument (Fixture)]),
                 Err_To_Out => True);
         begin
            Check
              (Result.Status /= 0
               and then Project_Tools.Text.Contains
                 (Text_Case.Lower (To_String (Result.Output)),
                  Text_Case.Lower (Expected)),
               "repository mutation was not rejected: " & Name & ": " &
               To_String (Result.Output));
         end;
         Fixtures.Cleanup (Fixture);
      exception
         when others =>
            Fixtures.Cleanup (Fixture);
            raise;
      end Expect_Rejected;
   begin
      for Item of Cases.All_Cases loop
         Expect_Rejected (Item);
      end loop;
   end Run;
end Giflib_Tooling.Mutation_Tests;
