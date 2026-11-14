with Ada.Finalization;

with Giflib_Tooling.Repository_Capture_Profiles;
with Giflib_Tooling.Repository_Searches;
with Giflib_Tooling.Repository_Snapshots;
with Giflib_Tooling.Repository_Source_Cache;
with Giflib_Tooling.Source_Limits;
with Giflib_Tooling.Validation_Storage_Budgets;
with Giflib_Tooling.Work_Budgets;

private package Giflib_Tooling.Analysis_Contexts is
   type Context (<>) is limited private;

   function Build
     (Root : String;
      Profile : Giflib_Tooling.Repository_Capture_Profiles.Capture_Profile :=
        Giflib_Tooling.Repository_Capture_Profiles.Complete_Repository;
      Limits : Giflib_Tooling.Source_Limits.Analysis_Limits :=
        Giflib_Tooling.Source_Limits.Default_Analysis_Limits;
      Cleanup_State : access Giflib_Tooling.Repository_Searches.Cleanup_Status :=
        null) return Context;

   procedure Inspect
     (Object : in out Context;
      Process : not null access procedure
        (Repository : aliased in Giflib_Tooling.Repository_Snapshots.Snapshot;
         Cached_Sources : aliased in
           Giflib_Tooling.Repository_Source_Cache.Cache;
         Work : aliased in out Giflib_Tooling.Work_Budgets.Budget;
         Storage : aliased in out
           Giflib_Tooling.Validation_Storage_Budgets.Budget));
private
   type Snapshot_Access is access Giflib_Tooling.Repository_Snapshots.Snapshot;
   type Cache_Access is access Giflib_Tooling.Repository_Source_Cache.Cache;
   type Analysis_Data_Owner is new Ada.Finalization.Limited_Controlled with
     record
      Repository : Snapshot_Access := null;
      Cached_Sources : Cache_Access := null;
   end record;
   overriding procedure Finalize (Object : in out Analysis_Data_Owner);
   type Context (Work_Limit : Natural; Storage_Limit : Natural) is
     limited record
      Data : Analysis_Data_Owner;
      Validation_Work : aliased Giflib_Tooling.Work_Budgets.Budget
        (Work_Limit);
      Validation_Storage : aliased
        Giflib_Tooling.Validation_Storage_Budgets.Budget (Storage_Limit);
   end record;
end Giflib_Tooling.Analysis_Contexts;
