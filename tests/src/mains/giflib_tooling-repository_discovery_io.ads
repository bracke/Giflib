with Ada.Directories;

with Giflib_Tooling.Repository_Diagnostics;

private package Giflib_Tooling.Repository_Discovery_IO is
   function Exists
     (Path : String;
      Failure : Giflib_Tooling.Repository_Diagnostics.Reason) return Boolean;
   function Canonical_Path
     (Path : String;
      Failure : Giflib_Tooling.Repository_Diagnostics.Reason) return String;
   function Is_Symbolic_Link
     (Path : String;
      Failure : Giflib_Tooling.Repository_Diagnostics.Reason) return Boolean;
   function Kind
     (Path : String;
      Failure : Giflib_Tooling.Repository_Diagnostics.Reason)
      return Ada.Directories.File_Kind;
end Giflib_Tooling.Repository_Discovery_IO;
