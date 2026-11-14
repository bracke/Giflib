with Giflib_Tooling.Repository_Handles;

private package Giflib_Tooling.Repository_Identity is
   function Canonical_Path (Path : String) return String;
   function Canonical_Root (Root : String) return String;
   function Resolve_Within (Canonical_Root : String; Path : String)
      return String;
   function Is_Canonical_Within
     (Canonical_Root : String; Canonical : String) return Boolean;
   function Descriptor_Path
     (File : Giflib_Tooling.Repository_Handles.Owner) return String;
   type Verification_Status is
     (Identity_Verified, Identity_Mismatch, Verification_Unavailable);
   function Opened_File_Status
     (File : Giflib_Tooling.Repository_Handles.Owner; Expected : String)
      return Verification_Status;
   function Opened_Directory_Status
     (File : Giflib_Tooling.Repository_Handles.Owner; Expected : String)
      return Verification_Status;
end Giflib_Tooling.Repository_Identity;
