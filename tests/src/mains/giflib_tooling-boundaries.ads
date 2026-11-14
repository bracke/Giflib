with Giflib_Tooling.Repository_Snapshots;
with Giflib_Tooling.Repository_Source_Cache;
with Giflib_Tooling.Work_Budgets;

private package Giflib_Tooling.Boundaries is
   procedure Validate_Static
     (Repository : Giflib_Tooling.Repository_Snapshots.Snapshot;
      Cached_Sources : Giflib_Tooling.Repository_Source_Cache.Cache;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget);
   procedure Validate_API (Root : String);
end Giflib_Tooling.Boundaries;
