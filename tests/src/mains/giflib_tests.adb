with AUnit;
with AUnit.Reporter.Text;
with AUnit.Run;
with Giflib_Testing.Suite;
with Project_Tools.Release_Checks;

procedure Giflib_Tests is
   use type AUnit.Status;

   function Run is new AUnit.Run.Test_Runner_With_Status (Giflib_Testing.Suite.All_Tests);
   Reporter : AUnit.Reporter.Text.Text_Reporter;
   Status : AUnit.Status;
begin
   Status := Run (Reporter);
   if Status /= AUnit.Success then
      begin
         Project_Tools.Release_Checks.Fail
           ("giflib_tests: AUnit suite failed", Quiet => True);
      exception
         when Program_Error =>
            null;
      end;
   end if;
end Giflib_Tests;
