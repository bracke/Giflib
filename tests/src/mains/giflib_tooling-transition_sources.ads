with Giflib_Tooling.Source_Units;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Vectors;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;

with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Work_Budgets;
with Giflib_Tooling.Repository_Snapshots;
with Giflib_Tooling.Repository_Source_Cache;
with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Validation_Storage_Budgets;

private package Giflib_Tooling.Transition_Sources is
   package Source renames Giflib_Tooling.Source_Model;
   package Budgets renames Giflib_Tooling.Work_Budgets;
   package Caches renames Giflib_Tooling.Repository_Source_Cache;

   type Repository is limited private;
   procedure Build
     (Object : in out Repository;
      Snapshot : Giflib_Tooling.Repository_Snapshots.Snapshot;
      Cached_Sources : Caches.Cache;
      Budget : in out Budgets.Budget;
      Storage : aliased in out
        Giflib_Tooling.Validation_Storage_Budgets.Budget);
   function Count (Object : Repository) return Natural;
   function Name_At (Object : Repository; Index : Positive) return String;
   function Contains (Object : Repository; Name : String) return Boolean;
   procedure Inspect
     (Object : Repository;
      Cached_Sources : Caches.Cache;
      Index : Positive;
      Budget : in out Budgets.Budget;
      Process : not null access procedure
        (Name : String;
         Parsed : Source.Parsed_Source;
         Clause : Giflib_Tooling.Source_Units.Separate_Clause));
   procedure Inspect
     (Object : Repository;
      Cached_Sources : Caches.Cache;
      Name : String;
      Budget : in out Budgets.Budget;
      Process : not null access procedure
        (Name : String;
         Parsed : Source.Parsed_Source;
         Clause : Giflib_Tooling.Source_Units.Separate_Clause));
   procedure Visit_Declarations
     (Object : Repository;
      Name : String;
      Process : not null access procedure
        (Type_Names : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
         Callable_Names : Giflib_Tooling.Name_Collections.Name_Vectors.Vector));
private
   use Ada.Strings.Unbounded;
   type Indexed_Unit is record
      Name : Unbounded_String;
      Path : Unbounded_String;
      Clause : Giflib_Tooling.Source_Units.Separate_Clause;
      Source_Length : Natural := 0;
      Type_Names : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
      Callable_Names : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
   end record;
   package Indexed_Unit_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Indexed_Unit);
   package Unit_Index_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type => String,
      Element_Type => Positive,
      Hash => Ada.Strings.Hash,
      Equivalent_Keys => "=");
   type Repository is limited record
      Units : Indexed_Unit_Vectors.Vector;
      Unit_Indices : Unit_Index_Maps.Map;
   end record;
end Giflib_Tooling.Transition_Sources;
