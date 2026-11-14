with Giflib_Tooling.Repository_Read_Race_Tests;
with Giflib_Tooling.Repository_Snapshot_Race_Tests;
with Giflib_Tooling.Repository_Traversal_Race_Tests;

package body Giflib_Tooling.Repository_Race_Tests is
   procedure Run is
   begin
      Giflib_Tooling.Repository_Read_Race_Tests.Run;
      Giflib_Tooling.Repository_Snapshot_Race_Tests.Run;
      Giflib_Tooling.Repository_Traversal_Race_Tests.Run;
   end Run;
end Giflib_Tooling.Repository_Race_Tests;
