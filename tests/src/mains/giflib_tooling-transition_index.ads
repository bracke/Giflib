with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Source_Units;
with Giflib_Tooling.Session_Identity;
with Giflib_Tooling.Work_Budgets;
with Giflib_Tooling.Session_Types;
with Giflib_Tooling.Transition_Sources;
with Giflib_Tooling.Transition_Context_Cache;
with Giflib_Tooling.Repository_Source_Cache;
with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Validation_Storage_Budgets;
with Giflib_Tooling.Repository_Snapshots;

private package Giflib_Tooling.Transition_Index is
   package Source renames Giflib_Tooling.Source_Model;
   package Semantics renames Giflib_Tooling.Session_Types;
   package Identity renames Giflib_Tooling.Session_Identity;
   package Budgets renames Giflib_Tooling.Work_Budgets;
   package Repositories renames Giflib_Tooling.Transition_Sources;
   package Context_Caches renames Giflib_Tooling.Transition_Context_Cache;

   package Source_Caches renames Giflib_Tooling.Repository_Source_Cache;
   type Resources
     (Repository : not null access constant
        Giflib_Tooling.Repository_Snapshots.Snapshot;
      Cached_Sources : not null access constant Source_Caches.Cache;
      Work : not null access Budgets.Budget;
      Storage : not null access
        Giflib_Tooling.Validation_Storage_Budgets.Budget) is limited private;
   type Source_Index (Bound : not null access Resources) is limited private;
   procedure Build
     (Object : in out Source_Index;
      Maximum_Context_Depth : Positive := Budgets.Maximum_Depth);
   procedure Inspect_Visible_Sources
     (Object : in out Source_Index;
      Prefix : String;
      Target_Name : String;
      Clause : Giflib_Tooling.Source_Units.Separate_Clause;
      Process : not null access procedure
        (Name : String;
         Type_Names : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
         Callable_Names : Giflib_Tooling.Name_Collections.Name_Vectors.Vector));
   procedure Scan_Family
     (Object : in out Source_Index;
      Prefix : String;
      Owner : String;
      Target_Type : Identity.Target;
      Process : not null access procedure
        (Name : String;
         Parsed : Source.Parsed_Source;
         Context : Semantics.Type_Classification_Vectors.Vector));
private
   type Resources
     (Repository : not null access constant
        Giflib_Tooling.Repository_Snapshots.Snapshot;
      Cached_Sources : not null access constant Source_Caches.Cache;
      Work : not null access Budgets.Budget;
      Storage : not null access
        Giflib_Tooling.Validation_Storage_Budgets.Budget) is limited null record;
   type Source_Index (Bound : not null access Resources) is limited record
      Sources : Repositories.Repository;
      Contexts : Context_Caches.Cache;
      Maximum_Context_Depth : Positive := Budgets.Maximum_Depth;
   end record;
end Giflib_Tooling.Transition_Index;
