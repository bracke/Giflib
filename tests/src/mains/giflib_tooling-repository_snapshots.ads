with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Indefinite_Vectors;
with Ada.Containers.Vectors;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;
with Giflib_Tooling.Repository_Capture_Profiles;
with Giflib_Tooling.Repository_Searches;
with Giflib_Tooling.Source_Limits;

private package Giflib_Tooling.Repository_Snapshots is
   type Snapshot is limited private;
   subtype Capture_Profile is
     Giflib_Tooling.Repository_Capture_Profiles.Capture_Profile;
   Complete_Repository : constant Capture_Profile :=
     Giflib_Tooling.Repository_Capture_Profiles.Complete_Repository;
   Source_Only : constant Capture_Profile :=
     Giflib_Tooling.Repository_Capture_Profiles.Source_Only;

   function Build
     (Root_Path : String;
      Profile : Capture_Profile := Complete_Repository;
      Limits : Giflib_Tooling.Source_Limits.Analysis_Limits :=
        Giflib_Tooling.Source_Limits.Default_Analysis_Limits;
      Cleanup_State : access Giflib_Tooling.Repository_Searches.Cleanup_Status :=
        null)
      return Snapshot;
   function Root (Object : Snapshot) return String;
   function Parsing_Limits_Of
     (Object : Snapshot) return Giflib_Tooling.Source_Limits.Parsing_Limits;
   function Cache_Limits_Of
     (Object : Snapshot) return Giflib_Tooling.Source_Limits.Cache_Limits;
   function Validation_Limits_Of
     (Object : Snapshot) return Giflib_Tooling.Source_Limits.Validation_Limits;
   function Contains (Object : Snapshot; Path : String) return Boolean;
   function Source_Length (Object : Snapshot; Path : String) return Natural;
   procedure Inspect_Text
     (Object : Snapshot;
      Path : String;
      Process : not null access procedure (Text : String));
   procedure Walk
     (Object : Snapshot;
      Directory : String;
      Process : not null access procedure (Path : String; Name : String));
private
   use Ada.Strings.Unbounded;
   type Snapshot_Entry
     (Path_Length : Natural;
      Name_Length : Natural;
      Text_Length : Natural) is record
      Path : String (1 .. Path_Length);
      Name : String (1 .. Name_Length);
      Text : String (1 .. Text_Length);
   end record;
   package Entry_Vectors is new Ada.Containers.Indefinite_Vectors
      (Index_Type => Positive, Element_Type => Snapshot_Entry);
   package Entry_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type => String,
      Element_Type => Positive,
      Hash => Ada.Strings.Hash,
      Equivalent_Keys => "=");
   package Entry_Index_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Positive);
   package Directory_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type => String,
      Element_Type => Entry_Index_Vectors.Vector,
      Hash => Ada.Strings.Hash,
      Equivalent_Keys => "=",
      "=" => Entry_Index_Vectors."=");
   type Snapshot is limited record
      Repository_Root : Unbounded_String;
      Entries : Entry_Vectors.Vector;
      Indices : Entry_Maps.Map;
      Directories : Directory_Maps.Map;
      Configuration : Giflib_Tooling.Source_Limits.Analysis_Limits :=
        Giflib_Tooling.Source_Limits.Default_Analysis_Limits;
      Total_Storage_Units : Natural := 0;
   end record;
end Giflib_Tooling.Repository_Snapshots;
