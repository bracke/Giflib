with Giflib_Tooling.Transition_Context_Cache_Tests;
with Giflib_Tooling.Transition_Source_Cache_Tests;

package body Giflib_Tooling.Transition_Cache_Tests is
   procedure Run is
   begin
      Giflib_Tooling.Transition_Context_Cache_Tests.Run;
      Giflib_Tooling.Transition_Source_Cache_Tests.Run;
   end Run;
end Giflib_Tooling.Transition_Cache_Tests;
