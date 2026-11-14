with Giflib_Tooling.Transition_Budget_Tests;
with Giflib_Tooling.Transition_Inspection_Tests;
with Giflib_Tooling.Transition_Policy_Tests;

package body Giflib_Tooling.Transition_Tests is
   procedure Run is
   begin
      Giflib_Tooling.Transition_Policy_Tests.Run;
      Giflib_Tooling.Transition_Inspection_Tests.Run;
      Giflib_Tooling.Transition_Budget_Tests.Run;
   end Run;
end Giflib_Tooling.Transition_Tests;
