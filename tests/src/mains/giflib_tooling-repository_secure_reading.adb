with Ada.Strings.Unbounded;
with GNAT.OS_Lib;

with Giflib_Tooling.Repository_Descriptor_Reading;
with Giflib_Tooling.Repository_Diagnostics;
with Giflib_Tooling.Repository_Handles;
with Giflib_Tooling.Repository_Identity;

package body Giflib_Tooling.Repository_Secure_Reading is
   use Ada.Strings.Unbounded;
   package Descriptor renames
     Giflib_Tooling.Repository_Descriptor_Reading;
   package Diagnostics renames Giflib_Tooling.Repository_Diagnostics;
   package Handles renames Giflib_Tooling.Repository_Handles;
   package Identity renames Giflib_Tooling.Repository_Identity;

   function Read_Bounded
     (Path : String;
      Required_Root : String;
      Maximum_Length : Natural;
      After_Open : access procedure := null;
      After_First_Read : access procedure := null;
      Before_Allocate : access procedure (Length : Natural) := null)
      return String
   is
      File : Handles.Owner;
      Opened_Canonical : Unbounded_String;

      procedure Require_Verified
        (Status : Identity.Verification_Status;
         Mismatch : Diagnostics.Reason) is
      begin
         case Status is
            when Identity.Identity_Verified =>
               null;
            when Identity.Identity_Mismatch =>
               Diagnostics.Raise_Input (Mismatch);
            when Identity.Verification_Unavailable =>
               Diagnostics.Raise_Input
                 (Diagnostics.Identity_Verification_Unavailable);
         end case;
      end Require_Verified;

      function Path_Still_Designates_Opened_File return Boolean
      is
         Descriptor_Path : constant String :=
           Identity.Descriptor_Path (File);
         Current : constant String := Identity.Canonical_Path (Path);
      begin
         return not GNAT.OS_Lib.Is_Symbolic_Link (Path)
           and then Descriptor_Path /= ""
           and then Identity.Canonical_Path (Descriptor_Path) =
             To_String (Opened_Canonical)
           and then Current = To_String (Opened_Canonical);
      end Path_Still_Designates_Opened_File;
   begin
      if GNAT.OS_Lib.Is_Symbolic_Link (Path) then
         Diagnostics.Raise_Input (Diagnostics.Symbolic_Link_Not_Allowed);
      elsif not Handles.Open_Read (File, Path) then
         Diagnostics.Raise_Input (Diagnostics.Input_Open_Failed);
      end if;
      declare
         Descriptor_Path : constant String :=
           Identity.Descriptor_Path (File);
      begin
         if Descriptor_Path = "" then
            Diagnostics.Raise_Input
              (Diagnostics.Identity_Verification_Unavailable);
         end if;
         Opened_Canonical := To_Unbounded_String
           (Identity.Canonical_Path (Descriptor_Path));
      end;
      if After_Open /= null then
         After_Open.all;
      end if;
      Require_Verified
        (Identity.Opened_File_Status
           (File, To_String (Opened_Canonical)),
         Diagnostics.Input_Identity_Changed_While_Opening);
      if To_String (Opened_Canonical) = ""
        or else not Path_Still_Designates_Opened_File
        or else
          (Required_Root /= ""
           and then not Identity.Is_Canonical_Within
             (Required_Root, To_String (Opened_Canonical)))
      then
         Diagnostics.Raise_Input
           (Diagnostics.Input_Identity_Changed_While_Opening);
      end if;
      declare
         Result : constant String := Descriptor.Read_Bounded
           (File, Maximum_Length, After_First_Read, Before_Allocate);
      begin
         Require_Verified
           (Identity.Opened_File_Status
              (File, To_String (Opened_Canonical)),
            Diagnostics.File_Changed_While_Reading);
         if not Path_Still_Designates_Opened_File then
            Diagnostics.Raise_Input
              (Diagnostics.File_Changed_While_Reading);
         end if;
         Handles.Close (File);
         return Result;
      end;
   end Read_Bounded;
end Giflib_Tooling.Repository_Secure_Reading;
