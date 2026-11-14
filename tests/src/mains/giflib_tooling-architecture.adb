with Giflib_Tooling.Architecture_Dependencies;
with Giflib_Tooling.Architecture_Interface;
with Giflib_Tooling.Architecture_Layout;
with Giflib_Tooling.Architecture_Ownership;

package body Giflib_Tooling.Architecture is
   procedure Validate
     (Repository : Giflib_Tooling.Repository_Snapshots.Snapshot;
      Cached_Sources : Giflib_Tooling.Repository_Source_Cache.Cache;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget) is
   begin
      Giflib_Tooling.Architecture_Interface.Validate
        (Repository, Cached_Sources, Budget);
      Giflib_Tooling.Architecture_Dependencies.Validate
        (Repository, Cached_Sources, Budget);
      Giflib_Tooling.Architecture_Ownership.Validate
        (Repository, Cached_Sources, Budget);
      Giflib_Tooling.Architecture_Layout.Validate
        (Repository, Cached_Sources, Budget);
   end Validate;
end Giflib_Tooling.Architecture;
