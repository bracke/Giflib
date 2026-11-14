with Giflib_Tooling.Repository_Snapshots;
with Giflib_Tooling.Repository_Source_Cache;
with Giflib_Tooling.Work_Budgets;
with Giflib_Tooling.Validation_Plans;

private package Giflib_Tooling.Repository_Validation is
   procedure Require_Main_Inventories
     (Repository : Giflib_Tooling.Repository_Snapshots.Snapshot;
      Cached_Sources : Giflib_Tooling.Repository_Source_Cache.Cache;
      Configuration : Giflib_Tooling.Validation_Plans.Plan;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget);

   procedure Require_Registered_Test_Packages
     (Repository : Giflib_Tooling.Repository_Snapshots.Snapshot;
      Cached_Sources : Giflib_Tooling.Repository_Source_Cache.Cache;
      Test_Directory : String;
      Suite_Path : String;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget);
end Giflib_Tooling.Repository_Validation;
