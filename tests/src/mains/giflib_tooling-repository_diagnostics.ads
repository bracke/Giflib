with Ada.Exceptions;

private package Giflib_Tooling.Repository_Diagnostics is
   type Reason is
     (Root_Canonicalization_Failed,
      Discovery_Directory_Identity_Changed,
      Directory_Open_Failed,
      Directory_Search_Failed,
      Directory_Search_Cleanup_Failed,
      Directory_Identity_Unverified,
      Identity_Verification_Unavailable,
      Discovery_Entry_Limit_Exceeded,
      Directory_Changed_During_Discovery,
      Entry_Identity_Changed_During_Discovery,
      Discovery_Escaped_Canonical_Root,
      Directory_Depth_Limit_Exceeded,
      Source_File_Limit_Exceeded,
      File_Length_Limit_Exceeded,
      Symbolic_Link_Not_Allowed,
      Input_Open_Failed,
      Input_Identity_Changed_While_Opening,
      File_Changed_While_Reading);

   function Message (Item : Reason) return String;
   function Is_Repository_Error
     (Occurrence : Ada.Exceptions.Exception_Occurrence) return Boolean;
   function Reason_Of
     (Occurrence : Ada.Exceptions.Exception_Occurrence) return Reason;
   function Rendered_Message
     (Occurrence : Ada.Exceptions.Exception_Occurrence) return String;
   procedure Raise_Input (Item : Reason) with No_Return;
end Giflib_Tooling.Repository_Diagnostics;
