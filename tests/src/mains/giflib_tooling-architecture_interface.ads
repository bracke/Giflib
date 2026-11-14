with Giflib_Tooling.Repository_Snapshots;
with Giflib_Tooling.Repository_Source_Cache;
with Giflib_Tooling.Work_Budgets;

private package Giflib_Tooling.Architecture_Interface is
   procedure Validate
     (Repository : Giflib_Tooling.Repository_Snapshots.Snapshot;
      Cached_Sources : Giflib_Tooling.Repository_Source_Cache.Cache;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget);
end Giflib_Tooling.Architecture_Interface;
