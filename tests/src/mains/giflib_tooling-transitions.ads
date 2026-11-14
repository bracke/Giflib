with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Repository_Snapshots;
with Giflib_Tooling.Repository_Source_Cache;
with Giflib_Tooling.Validation_Storage_Budgets;
with Giflib_Tooling.Work_Budgets;

private package Giflib_Tooling.Transitions is
   function Violation
     (Statement : Source_Tokens.Token_Vectors.Vector;
      Protected_Fields : Name_Collections.Name_Vectors.Vector;
      Session_Names : Name_Collections.Name_Vectors.Vector;
      Unit_Name : String := "") return Boolean;
   procedure Validate
     (Repository : aliased in Giflib_Tooling.Repository_Snapshots.Snapshot;
      Cached_Sources : aliased in
        Giflib_Tooling.Repository_Source_Cache.Cache;
      Budget : aliased in out Giflib_Tooling.Work_Budgets.Budget;
      Storage : aliased in out
        Giflib_Tooling.Validation_Storage_Budgets.Budget);
end Giflib_Tooling.Transitions;
