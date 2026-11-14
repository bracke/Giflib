with Giflib_Tooling.Repository_Snapshots;
with Giflib_Tooling.Repository_Source_Cache;
with Giflib_Tooling.Work_Budgets;

private package Giflib_Tooling.Repository_Test_Validation is
   procedure Require_Registered_Test_Packages
     (Repository : Giflib_Tooling.Repository_Snapshots.Snapshot;
      Cached_Sources : Giflib_Tooling.Repository_Source_Cache.Cache;
      Test_Directory : String;
      Suite_Path : String;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget);
end Giflib_Tooling.Repository_Test_Validation;
