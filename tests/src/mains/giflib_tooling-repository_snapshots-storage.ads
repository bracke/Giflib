private package Giflib_Tooling.Repository_Snapshots.Storage is
   procedure Require_Capacity
     (Object : Snapshot;
      Key : String;
      Text_Length : Natural;
      Include_Transient_Copy : Boolean);

   procedure Include_Empty_Directory
     (Object : in out Snapshot; Path : String);

   procedure Store
     (Object : in out Snapshot;
      Key : String;
      Text : String);
end Giflib_Tooling.Repository_Snapshots.Storage;
