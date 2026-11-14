with Ada.Unchecked_Deallocation;

package body Giflib_Tooling.Analysis_Contexts is
   package Snapshots renames Giflib_Tooling.Repository_Snapshots;
   package Caches renames Giflib_Tooling.Repository_Source_Cache;

   procedure Free is new Ada.Unchecked_Deallocation
     (Snapshots.Snapshot, Snapshot_Access);
   procedure Free is new Ada.Unchecked_Deallocation
     (Caches.Cache, Cache_Access);
   function Build
     (Root : String;
      Profile : Giflib_Tooling.Repository_Capture_Profiles.Capture_Profile :=
        Giflib_Tooling.Repository_Capture_Profiles.Complete_Repository;
      Limits : Giflib_Tooling.Source_Limits.Analysis_Limits :=
        Giflib_Tooling.Source_Limits.Default_Analysis_Limits;
      Cleanup_State : access Giflib_Tooling.Repository_Searches.Cleanup_Status :=
        null) return Context is
   begin
      return Result : Context
        (Work_Limit => Limits.Validation.Maximum_Validation_Work,
         Storage_Limit => Limits.Validation.Maximum_Validation_Storage_Units)
      do
         Result.Data.Repository :=
           new Snapshots.Snapshot'
             (Snapshots.Build
                (Root, Profile, Limits, Cleanup_State));
         Result.Data.Cached_Sources :=
           new Caches.Cache'
             (Caches.Build
                (Result.Data.Repository.all, Result.Validation_Work));
      end return;
   end Build;

   procedure Inspect
     (Object : in out Context;
      Process : not null access procedure
        (Repository : aliased in Snapshots.Snapshot;
         Cached_Sources : aliased in Caches.Cache;
         Work : aliased in out Giflib_Tooling.Work_Budgets.Budget;
         Storage : aliased in out
           Giflib_Tooling.Validation_Storage_Budgets.Budget)) is
   begin
      Process
        (Object.Data.Repository.all, Object.Data.Cached_Sources.all,
         Object.Validation_Work, Object.Validation_Storage);
   end Inspect;

   overriding procedure Finalize (Object : in out Analysis_Data_Owner) is
   begin
      Free (Object.Cached_Sources);
      Free (Object.Repository);
   end Finalize;
end Giflib_Tooling.Analysis_Contexts;
