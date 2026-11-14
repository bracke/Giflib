with Giflib_Tooling.Repository_Diagnostic_Tests;
with Giflib_Tooling.Repository_Limit_Tests;
with Giflib_Tooling.Repository_Race_Tests;

package body Giflib_Tooling.Repository_File_Tests is
   procedure Run is
   begin
      Giflib_Tooling.Repository_Diagnostic_Tests.Run;
      Giflib_Tooling.Repository_Race_Tests.Run;
      Giflib_Tooling.Repository_Limit_Tests.Run;
   end Run;
end Giflib_Tooling.Repository_File_Tests;
