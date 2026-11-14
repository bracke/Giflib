with Giflib_Tooling.Repository_Snapshots;

private package Giflib_Tooling.Repository_Validation_Support is
   procedure Inspect_File
     (Repository : Giflib_Tooling.Repository_Snapshots.Snapshot;
      Relative_Path : String;
      Process : not null access procedure (Text : String));
   function Stem (Name : String) return String;
   function Package_Name (File_Name : String) return String;
end Giflib_Tooling.Repository_Validation_Support;
