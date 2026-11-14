package body Giflib_Tooling.Repository_Diagnostics is
   Root_Canonicalization_Error : exception;
   Discovery_Directory_Identity_Error : exception;
   Directory_Open_Error : exception;
   Directory_Search_Error : exception;
   Directory_Search_Cleanup_Error : exception;
   Directory_Identity_Error : exception;
   Identity_Verification_Unavailable_Error : exception;
   Discovery_Entry_Limit_Error : exception;
   Directory_Changed_Error : exception;
   Entry_Identity_Changed_Error : exception;
   Discovery_Escaped_Root_Error : exception;
   Directory_Depth_Limit_Error : exception;
   Source_File_Limit_Error : exception;
   File_Length_Limit_Error : exception;
   Symbolic_Link_Error : exception;
   Input_Open_Error : exception;
   Input_Identity_Changed_Error : exception;
   File_Changed_Error : exception;

   use type Ada.Exceptions.Exception_Id;

   function Message (Item : Reason) return String is
     (case Item is
         when Root_Canonicalization_Failed =>
           "repository root cannot be canonicalized",
         when Discovery_Directory_Identity_Changed =>
           "repository discovery directory identity changed",
         when Directory_Open_Failed =>
           "repository directory cannot be opened",
         when Directory_Search_Failed =>
           "repository directory cannot be searched",
         when Directory_Search_Cleanup_Failed =>
           "repository directory search cleanup failed",
         when Directory_Identity_Unverified =>
           "repository directory identity cannot be verified",
         when Identity_Verification_Unavailable =>
           "repository descriptor identity verification is unavailable",
         when Discovery_Entry_Limit_Exceeded =>
           "repository discovery entry limit exceeded",
         when Directory_Changed_During_Discovery =>
           "repository directory changed during discovery",
         when Entry_Identity_Changed_During_Discovery =>
           "repository entry identity changed during discovery",
         when Discovery_Escaped_Canonical_Root =>
           "repository discovery escaped its canonical root",
         when Directory_Depth_Limit_Exceeded =>
           "repository directory depth limit exceeded",
         when Source_File_Limit_Exceeded =>
           "repository file limit exceeded",
         when File_Length_Limit_Exceeded =>
           "repository file length limit exceeded",
         when Symbolic_Link_Not_Allowed =>
           "symbolic links are not allowed for repository inputs",
         when Input_Open_Failed =>
           "repository input cannot be opened",
         when Input_Identity_Changed_While_Opening =>
           "repository input identity changed while opening",
         when File_Changed_While_Reading =>
           "repository file changed while reading");

   function Identity_Of (Item : Reason) return Ada.Exceptions.Exception_Id is
     (case Item is
         when Root_Canonicalization_Failed =>
           Root_Canonicalization_Error'Identity,
         when Discovery_Directory_Identity_Changed =>
           Discovery_Directory_Identity_Error'Identity,
         when Directory_Open_Failed => Directory_Open_Error'Identity,
         when Directory_Search_Failed => Directory_Search_Error'Identity,
         when Directory_Search_Cleanup_Failed =>
           Directory_Search_Cleanup_Error'Identity,
         when Directory_Identity_Unverified => Directory_Identity_Error'Identity,
         when Identity_Verification_Unavailable =>
           Identity_Verification_Unavailable_Error'Identity,
         when Discovery_Entry_Limit_Exceeded =>
           Discovery_Entry_Limit_Error'Identity,
         when Directory_Changed_During_Discovery =>
           Directory_Changed_Error'Identity,
         when Entry_Identity_Changed_During_Discovery =>
           Entry_Identity_Changed_Error'Identity,
         when Discovery_Escaped_Canonical_Root =>
           Discovery_Escaped_Root_Error'Identity,
         when Directory_Depth_Limit_Exceeded =>
           Directory_Depth_Limit_Error'Identity,
         when Source_File_Limit_Exceeded => Source_File_Limit_Error'Identity,
         when File_Length_Limit_Exceeded => File_Length_Limit_Error'Identity,
         when Symbolic_Link_Not_Allowed => Symbolic_Link_Error'Identity,
         when Input_Open_Failed => Input_Open_Error'Identity,
         when Input_Identity_Changed_While_Opening =>
           Input_Identity_Changed_Error'Identity,
         when File_Changed_While_Reading => File_Changed_Error'Identity);

   function Is_Repository_Error
     (Occurrence : Ada.Exceptions.Exception_Occurrence) return Boolean
   is
      Identity : constant Ada.Exceptions.Exception_Id :=
        Ada.Exceptions.Exception_Identity (Occurrence);
   begin
      for Item in Reason loop
         if Identity = Identity_Of (Item) then
            return True;
         end if;
      end loop;
      return False;
   end Is_Repository_Error;

   function Reason_Of
     (Occurrence : Ada.Exceptions.Exception_Occurrence) return Reason
   is
      Identity : constant Ada.Exceptions.Exception_Id :=
        Ada.Exceptions.Exception_Identity (Occurrence);
   begin
      for Item in Reason loop
         if Identity = Identity_Of (Item) then
            return Item;
         end if;
      end loop;
      raise Program_Error with "occurrence is not a repository error";
   end Reason_Of;

   function Rendered_Message
     (Occurrence : Ada.Exceptions.Exception_Occurrence) return String is
     (Message (Reason_Of (Occurrence)));

   procedure Raise_Input (Item : Reason) is
   begin
      case Item is
         when Root_Canonicalization_Failed =>
            raise Root_Canonicalization_Error with Message (Item);
         when Discovery_Directory_Identity_Changed =>
            raise Discovery_Directory_Identity_Error with Message (Item);
         when Directory_Open_Failed =>
            raise Directory_Open_Error with Message (Item);
         when Directory_Search_Failed =>
            raise Directory_Search_Error with Message (Item);
         when Directory_Search_Cleanup_Failed =>
            raise Directory_Search_Cleanup_Error with Message (Item);
         when Directory_Identity_Unverified =>
            raise Directory_Identity_Error with Message (Item);
         when Identity_Verification_Unavailable =>
            raise Identity_Verification_Unavailable_Error with Message (Item);
         when Discovery_Entry_Limit_Exceeded =>
            raise Discovery_Entry_Limit_Error with Message (Item);
         when Directory_Changed_During_Discovery =>
            raise Directory_Changed_Error with Message (Item);
         when Entry_Identity_Changed_During_Discovery =>
            raise Entry_Identity_Changed_Error with Message (Item);
         when Discovery_Escaped_Canonical_Root =>
            raise Discovery_Escaped_Root_Error with Message (Item);
         when Directory_Depth_Limit_Exceeded =>
            raise Directory_Depth_Limit_Error with Message (Item);
         when Source_File_Limit_Exceeded =>
            raise Source_File_Limit_Error with Message (Item);
         when File_Length_Limit_Exceeded =>
            raise File_Length_Limit_Error with Message (Item);
         when Symbolic_Link_Not_Allowed =>
            raise Symbolic_Link_Error with Message (Item);
         when Input_Open_Failed =>
            raise Input_Open_Error with Message (Item);
         when Input_Identity_Changed_While_Opening =>
            raise Input_Identity_Changed_Error with Message (Item);
         when File_Changed_While_Reading =>
            raise File_Changed_Error with Message (Item);
      end case;
   end Raise_Input;
end Giflib_Tooling.Repository_Diagnostics;
