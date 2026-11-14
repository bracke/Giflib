with Giflib_Tooling.Source_Names;

package body Giflib_Tooling.Repository_Validation_Support is
   package Snapshots renames Giflib_Tooling.Repository_Snapshots;
   package Source_Names renames Giflib_Tooling.Source_Names;

   procedure Inspect_File
     (Repository : Snapshots.Snapshot;
      Relative_Path : String;
      Process : not null access procedure (Text : String)) is
   begin
      Snapshots.Inspect_Text
        (Repository, Relative_Path, Process);
   end Inspect_File;

   function Stem (Name : String) return String is
     (if Name'Length > 4
        and then Name (Name'Last - 3 .. Name'Last) in ".ads" | ".adb"
      then Name (Name'First .. Name'Last - 4)
      else Name);

   function Package_Name (File_Name : String) return String is
     (Source_Names.Unit_Name (File_Name));
end Giflib_Tooling.Repository_Validation_Support;
