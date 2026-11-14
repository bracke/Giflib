with Giflib_Tooling.Repository_Project_Validation;
with Giflib_Tooling.Repository_Test_Validation;

package body Giflib_Tooling.Repository_Validation is
   procedure Require_Main_Inventories
     (Repository : Giflib_Tooling.Repository_Snapshots.Snapshot;
      Cached_Sources : Giflib_Tooling.Repository_Source_Cache.Cache;
      Configuration : Giflib_Tooling.Validation_Plans.Plan;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget) is
   begin
      Giflib_Tooling.Repository_Project_Validation.Require_Main_Inventories
        (Repository, Cached_Sources, Configuration, Budget);
   end Require_Main_Inventories;

   procedure Require_Registered_Test_Packages
     (Repository : Giflib_Tooling.Repository_Snapshots.Snapshot;
      Cached_Sources : Giflib_Tooling.Repository_Source_Cache.Cache;
      Test_Directory : String;
      Suite_Path : String;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget) is
   begin
      Giflib_Tooling.Repository_Test_Validation
        .Require_Registered_Test_Packages
          (Repository, Cached_Sources, Test_Directory, Suite_Path, Budget);
   end Require_Registered_Test_Packages;
end Giflib_Tooling.Repository_Validation;
