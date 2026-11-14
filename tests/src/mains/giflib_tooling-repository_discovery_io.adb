with GNAT.OS_Lib;

with Giflib_Tooling.Repository_Identity;

package body Giflib_Tooling.Repository_Discovery_IO is
   package Diagnostics renames Giflib_Tooling.Repository_Diagnostics;

   function Exists
     (Path : String; Failure : Diagnostics.Reason) return Boolean is
   begin
      return Ada.Directories.Exists (Path);
   exception
      when Ada.Directories.Name_Error | Ada.Directories.Use_Error |
           Ada.Directories.Status_Error =>
         Diagnostics.Raise_Input (Failure);
   end Exists;

   function Canonical_Path
     (Path : String; Failure : Diagnostics.Reason) return String is
   begin
      return Giflib_Tooling.Repository_Identity.Canonical_Path (Path);
   exception
      when Ada.Directories.Name_Error | Ada.Directories.Use_Error |
           Ada.Directories.Status_Error =>
         Diagnostics.Raise_Input (Failure);
   end Canonical_Path;

   function Is_Symbolic_Link
     (Path : String; Failure : Diagnostics.Reason) return Boolean is
   begin
      return GNAT.OS_Lib.Is_Symbolic_Link (Path);
   exception
      when Ada.Directories.Name_Error | Ada.Directories.Use_Error |
           Ada.Directories.Status_Error =>
         Diagnostics.Raise_Input (Failure);
   end Is_Symbolic_Link;

   function Kind
     (Path : String; Failure : Diagnostics.Reason)
      return Ada.Directories.File_Kind is
   begin
      return Ada.Directories.Kind (Path);
   exception
      when Ada.Directories.Name_Error | Ada.Directories.Use_Error |
           Ada.Directories.Status_Error =>
         Diagnostics.Raise_Input (Failure);
   end Kind;
end Giflib_Tooling.Repository_Discovery_IO;
