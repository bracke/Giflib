with Giflib_Tooling.Session_Expression_Tests;
with Giflib_Tooling.Session_Identity_Tests;
with Giflib_Tooling.Session_Resolution_Tests;

package body Giflib_Tooling.Session_State_Tests is
   procedure Run is
   begin
      Giflib_Tooling.Session_Identity_Tests.Run;
      Giflib_Tooling.Session_Resolution_Tests.Run;
      Giflib_Tooling.Session_Expression_Tests.Run;
   end Run;
end Giflib_Tooling.Session_State_Tests;
