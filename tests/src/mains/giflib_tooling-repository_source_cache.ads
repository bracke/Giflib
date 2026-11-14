with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Vectors;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;

with Giflib_Tooling.Repository_Snapshots;
with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Work_Budgets;

private package Giflib_Tooling.Repository_Source_Cache is
   type Cache is limited private;

   function Build
     (Repository : Giflib_Tooling.Repository_Snapshots.Snapshot;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget) return Cache;
   function Source_Length (Object : Cache; Path : String) return Natural;
   procedure Inspect
     (Object : Cache;
      Path : String;
      Process : not null access procedure
        (Parsed : Giflib_Tooling.Source_Model.Parsed_Source));
private
   use Ada.Strings.Unbounded;
   type Cached_Source is record
      Path : Unbounded_String;
      Parsed : Giflib_Tooling.Source_Model.Parsed_Source;
      Text_Length : Natural := 0;
   end record;
   package Source_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Cached_Source);
   package Source_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type => String,
      Element_Type => Positive,
      Hash => Ada.Strings.Hash,
      Equivalent_Keys => "=");
   type Cache is limited record
      Repository_Root : Unbounded_String;
      Sources : Source_Vectors.Vector;
      Indices : Source_Maps.Map;
      Model_Units : Natural := 0;
   end record;
end Giflib_Tooling.Repository_Source_Cache;
