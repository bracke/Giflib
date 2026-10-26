with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Directories;

with Project_Tools.Files;
with Project_Tools.Release_Checks;

with Giflib_Tooling.Self_Tests;

procedure Giflib_Tooling_Tests is
   Root : constant String :=
     Project_Tools.Files.Find_Root_Upward
       (Ada.Directories.Current_Directory, "giflib.gpr");
   Probe : constant String :=
     Project_Tools.Files.Join
       (Ada.Directories.Containing_Directory (Ada.Command_Line.Command_Name),
        "giflib_tooling_probe");
begin
   Giflib_Tooling.Self_Tests.Run;
   Giflib_Tooling.Self_Tests.Run_Mutations (Root, Probe);
   Ada.Text_IO.Put_Line ("giflib tooling tests passed");
exception
   when Program_Error =>
      raise;
   when others =>
      Project_Tools.Release_Checks.Fail
        ("giflib tooling tests raised an unexpected exception");
end Giflib_Tooling_Tests;
