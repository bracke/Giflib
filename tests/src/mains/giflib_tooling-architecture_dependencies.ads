with Project_Tools.Ada_Source;
with Giflib_Tooling.Repository_Snapshots;
with Giflib_Tooling.Repository_Source_Cache;
with Giflib_Tooling.Work_Budgets;

private package Giflib_Tooling.Architecture_Dependencies is
   procedure Require_Only_Allowed_With_Clauses
     (Cached_Sources : Giflib_Tooling.Repository_Source_Cache.Cache;
      Path : String;
      Prefix : String;
      Allowed : Project_Tools.Ada_Source.String_List;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget);
   procedure Validate
     (Repository : Giflib_Tooling.Repository_Snapshots.Snapshot;
      Cached_Sources : Giflib_Tooling.Repository_Source_Cache.Cache;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget);
end Giflib_Tooling.Architecture_Dependencies;
