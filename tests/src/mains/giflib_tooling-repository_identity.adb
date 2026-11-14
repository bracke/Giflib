with Giflib_Tooling.Repository_Diagnostics;
with GNAT.OS_Lib;
with Project_Tools.Files;

package body Giflib_Tooling.Repository_Identity is
   package Handles renames Giflib_Tooling.Repository_Handles;
   package Diagnostics renames Giflib_Tooling.Repository_Diagnostics;
   function Canonical_Path (Path : String) return String is
     (GNAT.OS_Lib.Normalize_Pathname
        (Path, Resolve_Links => True, Case_Sensitive => False));

   function Descriptor_Path
     (File : Handles.Owner) return String is
     (Handles.Descriptor_Path (File));

   function Opened_File_Status
     (File : Handles.Owner; Expected : String)
      return Verification_Status
   is
   begin
      if not Handles.Is_Open (File) or else Expected = "" then
         return Identity_Mismatch;
      end if;
      declare
         Path : constant String := Descriptor_Path (File);
      begin
         if Path = "" then
            return Verification_Unavailable;
         elsif Handles.Is_Regular_File (File)
           and then Canonical_Path (Path) = Expected
         then
            return Identity_Verified;
         end if;
         return Identity_Mismatch;
      end;
   end Opened_File_Status;

   function Opened_Directory_Status
     (File : Handles.Owner; Expected : String)
      return Verification_Status
   is
   begin
      if not Handles.Is_Open (File) or else Expected = "" then
         return Identity_Mismatch;
      end if;
      declare
         Path : constant String := Descriptor_Path (File);
      begin
         if Path = "" then
            return Verification_Unavailable;
         elsif Handles.Is_Directory (File)
           and then Canonical_Path (Path) = Expected
         then
            return Identity_Verified;
         end if;
         return Identity_Mismatch;
      end;
   end Opened_Directory_Status;

   function Canonical_Root (Root : String) return String is
      Result : constant String := Canonical_Path (Root);
   begin
      if Result = "" then
         Diagnostics.Raise_Input (Diagnostics.Root_Canonicalization_Failed);
      end if;
      return Result;
   end Canonical_Root;

   function Resolve_Within
     (Canonical_Root : String; Path : String) return String
   is
      Candidate : constant String :=
        (if GNAT.OS_Lib.Is_Absolute_Path (Path)
         then Path
         else Project_Tools.Files.Join (Canonical_Root, Path));
      Result : constant String := GNAT.OS_Lib.Normalize_Pathname
        (Candidate, Resolve_Links => False, Case_Sensitive => False);
   begin
      return
        (if Is_Canonical_Within (Canonical_Root, Result) then Result else "");
   end Resolve_Within;

   function Is_Canonical_Within
     (Canonical_Root : String; Canonical : String) return Boolean
   is
      Prefix : constant String :=
        (if Canonical_Root /= ""
           and then Canonical_Root (Canonical_Root'Last) =
             GNAT.OS_Lib.Directory_Separator
         then Canonical_Root
         else Canonical_Root & GNAT.OS_Lib.Directory_Separator);
   begin
      return Canonical_Root /= ""
        and then Canonical /= ""
        and then
          (Canonical = Canonical_Root
           or else
             (Canonical'Length > Prefix'Length
              and then Canonical
                (Canonical'First .. Canonical'First + Prefix'Length - 1) =
                  Prefix));
   end Is_Canonical_Within;
end Giflib_Tooling.Repository_Identity;
