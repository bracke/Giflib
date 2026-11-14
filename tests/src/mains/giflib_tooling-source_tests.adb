with Giflib_Tooling.Source_Lexing_Tests;
with Giflib_Tooling.Source_Limit_Tests;
with Giflib_Tooling.Source_Structure_Tests;

package body Giflib_Tooling.Source_Tests is
   procedure Run is
   begin
      Giflib_Tooling.Source_Lexing_Tests.Run;
      Giflib_Tooling.Source_Limit_Tests.Run;
      Giflib_Tooling.Source_Structure_Tests.Run;
   end Run;
end Giflib_Tooling.Source_Tests;
