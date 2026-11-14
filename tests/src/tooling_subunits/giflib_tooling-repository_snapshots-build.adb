with Ada.Directories;
with Project_Tools.Files;

with Giflib_Tooling.Repository_Files;
with Giflib_Tooling.Repository_Handles;
with Giflib_Tooling.Repository_Identity;
with Giflib_Tooling.Repository_Snapshots.Storage;

separate (Giflib_Tooling.Repository_Snapshots)
function Build
  (Root_Path : String;
   Profile : Capture_Profile := Complete_Repository;
   Limits : Giflib_Tooling.Source_Limits.Analysis_Limits :=
     Giflib_Tooling.Source_Limits.Default_Analysis_Limits;
   Cleanup_State : access Giflib_Tooling.Repository_Searches.Cleanup_Status :=
     null)
   return Snapshot
is
   use type Ada.Directories.File_Kind;
   package Files renames Project_Tools.Files;
   package Identity renames Giflib_Tooling.Repository_Identity;
   package Repository_Files renames Giflib_Tooling.Repository_Files;
   package Snapshot_Storage renames
     Giflib_Tooling.Repository_Snapshots.Storage;

   procedure Remember
     (Object : in out Snapshot;
      Path : String;
      Required : Boolean := True) is
   begin
      if not Ada.Directories.Exists (Path) then
         if Required then
            raise Input_Error with
              "required repository snapshot file is missing: " & Path;
         end if;
         return;
      elsif Ada.Directories.Kind (Path) /= Ada.Directories.Ordinary_File then
         raise Input_Error with
           "repository snapshot entry is not a regular file: " & Path;
      end if;
      declare
         Key : constant String := Identity.Canonical_Path (Path);
      begin
         if Key = "" then
            raise Input_Error with
              "required repository snapshot file cannot be canonicalized: " &
              Path;
         elsif Object.Indices.Contains (Key) then
            return;
         end if;
         declare
            procedure Reserve (Length : Natural) is
            begin
               Snapshot_Storage.Require_Capacity
                 (Object, Key, Length, Include_Transient_Copy => True);
            end Reserve;
            Text : constant String := Repository_Files.Read_Bounded_Within
              (Root (Object), Key,
               Object.Configuration.Parsing.Maximum_Source_Length,
               Reserve'Access);
         begin
            Snapshot_Storage.Store (Object, Key, Text);
         end;
      end;
   end Remember;

   procedure Remember_Opened
     (Object : in out Snapshot;
      Path : String;
      File : Giflib_Tooling.Repository_Handles.Owner)
   is
      procedure Reserve (Length : Natural) is
      begin
         Snapshot_Storage.Require_Capacity
           (Object, Path, Length, Include_Transient_Copy => True);
      end Reserve;
      Text : constant String :=
        Repository_Files.Read_Pinned_Bounded
          (File, Object.Configuration.Parsing.Maximum_Source_Length,
           Reserve'Access);
   begin
      Snapshot_Storage.Store (Object, Path, Text);
   end Remember_Opened;

   procedure Capture_Directory
     (Object : in out Snapshot;
      Relative_Path : String;
      Required : Boolean)
   is
      procedure Include
        (Path : String;
         Name : String;
         File : Giflib_Tooling.Repository_Handles.Owner) is
         pragma Unreferenced (Name);
      begin
         Remember_Opened (Object, Path, File);
      end Include;
      Path : constant String := Files.Join (Root (Object), Relative_Path);
   begin
      if not Ada.Directories.Exists (Path) then
         if Required then
            raise Input_Error with
              "required repository snapshot directory is missing: " & Path;
         end if;
         return;
      elsif Ada.Directories.Kind (Path) /= Ada.Directories.Directory then
         raise Input_Error with
           "repository snapshot path is not a directory: " & Path;
      end if;
      Snapshot_Storage.Include_Empty_Directory
        (Object, Identity.Canonical_Path (Path));
      Repository_Files.Walk_Opened
        (Path, Include'Access,
         Object.Configuration.Discovery,
         Object.Configuration.Parsing.Maximum_Source_Length,
         Cleanup_State);
   end Capture_Directory;
begin
   return Result : Snapshot do
      Result.Configuration := Limits;
      Result.Repository_Root := To_Unbounded_String
        (Repository_Files.Canonical_Root (Root_Path));
      if Length (Result.Repository_Root) = 0 then
         raise Input_Error with "cannot canonicalize repository root";
      end if;
      declare
         procedure Include_Directory
           (Relative_Path : String; Required : Boolean) is
         begin
            Capture_Directory (Result, Relative_Path, Required);
         end Include_Directory;

         procedure Include_File
           (Relative_Path : String; Required : Boolean) is
         begin
            Remember
              (Result, Files.Join (Root (Result), Relative_Path), Required);
         end Include_File;
      begin
         Giflib_Tooling.Repository_Capture_Profiles.Visit
           (Profile, Include_Directory'Access, Include_File'Access);
      end;
   end return;
end Build;
