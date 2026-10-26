with Ada.Text_IO;

with Project_Tools.Release_Checks;

with Giflib_Tooling.Self_Tests;

procedure Giflib_Tooling_Tests is
begin
   Giflib_Tooling.Self_Tests.Run;
   Ada.Text_IO.Put_Line ("giflib tooling tests passed");
exception
   when Program_Error =>
      raise;
   when others =>
      Project_Tools.Release_Checks.Fail
        ("giflib tooling tests raised an unexpected exception");
end Giflib_Tooling_Tests;
