with Giflib_Tooling.Transition_Context_Failure_Tests;
with Giflib_Tooling.Transition_Context_Success_Tests;

package body Giflib_Tooling.Transition_Context_Tests is
   procedure Run is
   begin
      Giflib_Tooling.Transition_Context_Success_Tests.Run;
      Giflib_Tooling.Transition_Context_Failure_Tests.Run;
   end Run;
end Giflib_Tooling.Transition_Context_Tests;
