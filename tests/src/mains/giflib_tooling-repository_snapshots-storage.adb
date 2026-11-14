with Ada.Directories;
with Giflib_Tooling.Repository_Identity;

package body Giflib_Tooling.Repository_Snapshots.Storage is
   package Identity renames Giflib_Tooling.Repository_Identity;

   procedure Visit_Ancestors
     (Object : Snapshot;
      Key : String;
      Process : not null access procedure (Directory : String))
   is
      Directory : Unbounded_String := To_Unbounded_String
        (Ada.Directories.Containing_Directory (Key));
   begin
      while Length (Directory) > 0
        and then Identity.Is_Canonical_Within
          (Root (Object), To_String (Directory))
      loop
         Process (To_String (Directory));
         exit when To_String (Directory) = Root (Object);
         Directory := To_Unbounded_String
           (Ada.Directories.Containing_Directory (To_String (Directory)));
      end loop;
   end Visit_Ancestors;

   function Required_Storage_Units
     (Object : Snapshot;
      Key : String;
      Text_Length : Natural) return Natural
   is
      Total : Long_Long_Integer :=
        2 + Long_Long_Integer (Text_Length)
        + 2 * Long_Long_Integer (Key'Length)
        + Long_Long_Integer (Ada.Directories.Simple_Name (Key)'Length);
      procedure Count_Directory (Directory : String) is
      begin
         Total := Total + 1;
         if not Object.Directories.Contains (Directory) then
            Total := Total + 1 + Long_Long_Integer (Directory'Length);
         end if;
      end Count_Directory;
   begin
      Visit_Ancestors (Object, Key, Count_Directory'Access);
      return Natural
        (Long_Long_Integer'Min
           (Long_Long_Integer (Natural'Last), Total));
   end Required_Storage_Units;

   procedure Require_Capacity
     (Object : Snapshot;
      Key : String;
      Text_Length : Natural;
      Include_Transient_Copy : Boolean)
   is
      Required : constant Natural :=
        Required_Storage_Units (Object, Key, Text_Length);
      Transient : constant Natural :=
        (if Include_Transient_Copy then Text_Length else 0);
      Limit : constant Natural :=
        Object.Configuration.Snapshot.Maximum_Storage_Units;
   begin
      if Natural (Object.Entries.Length) >=
        Object.Configuration.Snapshot.Maximum_Files
      then
         raise Input_Error with "repository snapshot file limit exceeded";
      elsif Required > Limit - Object.Total_Storage_Units
        or else Transient > Limit - Object.Total_Storage_Units - Required
      then
         raise Input_Error with
           "repository snapshot storage-unit limit exceeded";
      end if;
   end Require_Capacity;

   procedure Include_Empty_Directory
     (Object : in out Snapshot; Path : String)
   is
      Units : constant Natural := 1 + Path'Length;
      Limit : constant Natural :=
        Object.Configuration.Snapshot.Maximum_Storage_Units;
   begin
      if Object.Directories.Contains (Path) then
         return;
      elsif Units > Limit - Object.Total_Storage_Units then
         raise Input_Error with
           "repository snapshot storage-unit limit exceeded";
      end if;
      Object.Directories.Insert (Path, Entry_Index_Vectors.Empty_Vector);
      Object.Total_Storage_Units := Object.Total_Storage_Units + Units;
   end Include_Empty_Directory;

   procedure Store
     (Object : in out Snapshot;
      Key : String;
      Text : String)
   is
   begin
      if Key = "" then
         raise Input_Error with
           "required repository snapshot file cannot be canonicalized";
      elsif Object.Indices.Contains (Key) then
         return;
      end if;
      Require_Capacity
        (Object, Key, Text'Length, Include_Transient_Copy => False);
      declare
         Retained_Units : constant Natural :=
           Required_Storage_Units (Object, Key, Text'Length);
         Name : constant String := Ada.Directories.Simple_Name (Key);
         procedure Index_Directory (Directory : String) is
         begin
            if not Object.Directories.Contains (Directory) then
               Object.Directories.Insert
                 (Directory, Entry_Index_Vectors.Empty_Vector);
            end if;
            Object.Directories (Directory).Append
              (Object.Entries.Last_Index);
         end Index_Directory;
      begin
         Object.Entries.Append
           (Snapshot_Entry'
              (Path_Length => Key'Length,
               Name_Length => Name'Length,
               Text_Length => Text'Length,
               Path => Key, Name => Name, Text => Text));
         Object.Indices.Insert (Key, Object.Entries.Last_Index);
         Visit_Ancestors (Object, Key, Index_Directory'Access);
         Object.Total_Storage_Units :=
           Object.Total_Storage_Units + Retained_Units;
      end;
   end Store;
end Giflib_Tooling.Repository_Snapshots.Storage;
