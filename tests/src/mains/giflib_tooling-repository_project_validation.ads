with Giflib_Tooling.Repository_Snapshots;
with Giflib_Tooling.Repository_Source_Cache;
with Giflib_Tooling.Validation_Plans;
with Giflib_Tooling.Work_Budgets;

private package Giflib_Tooling.Repository_Project_Validation is
   procedure Require_Main_Inventories
     (Repository : Giflib_Tooling.Repository_Snapshots.Snapshot;
      Cached_Sources : Giflib_Tooling.Repository_Source_Cache.Cache;
      Configuration : Giflib_Tooling.Validation_Plans.Plan;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget);
end Giflib_Tooling.Repository_Project_Validation;
