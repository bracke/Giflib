with Ada.Directories;

with Giflib_Tooling.Repository_Diagnostics;
with Giflib_Tooling.Repository_Discovery_IO;
with Giflib_Tooling.Repository_Searches;
with Giflib_Tooling.Self_Test_Support;

package body Giflib_Tooling.Repository_Diagnostic_Tests is
   use type Giflib_Tooling.Repository_Diagnostics.Reason;
   package Check renames Giflib_Tooling.Self_Test_Support;
   package Diagnostics renames Giflib_Tooling.Repository_Diagnostics;
   package Discovery_IO renames Giflib_Tooling.Repository_Discovery_IO;
   package Searches renames Giflib_Tooling.Repository_Searches;

   function Expected_Message (Item : Diagnostics.Reason) return String is
     (case Item is
         when Diagnostics.Root_Canonicalization_Failed =>
           "repository root cannot be canonicalized",
         when Diagnostics.Discovery_Directory_Identity_Changed =>
           "repository discovery directory identity changed",
         when Diagnostics.Directory_Open_Failed =>
           "repository directory cannot be opened",
         when Diagnostics.Directory_Search_Failed =>
           "repository directory cannot be searched",
         when Diagnostics.Directory_Search_Cleanup_Failed =>
           "repository directory search cleanup failed",
         when Diagnostics.Directory_Identity_Unverified =>
           "repository directory identity cannot be verified",
         when Diagnostics.Identity_Verification_Unavailable =>
           "repository descriptor identity verification is unavailable",
         when Diagnostics.Discovery_Entry_Limit_Exceeded =>
           "repository discovery entry limit exceeded",
         when Diagnostics.Directory_Changed_During_Discovery =>
           "repository directory changed during discovery",
         when Diagnostics.Entry_Identity_Changed_During_Discovery =>
           "repository entry identity changed during discovery",
         when Diagnostics.Discovery_Escaped_Canonical_Root =>
           "repository discovery escaped its canonical root",
         when Diagnostics.Directory_Depth_Limit_Exceeded =>
           "repository directory depth limit exceeded",
         when Diagnostics.Source_File_Limit_Exceeded =>
           "repository file limit exceeded",
         when Diagnostics.File_Length_Limit_Exceeded =>
           "repository file length limit exceeded",
         when Diagnostics.Symbolic_Link_Not_Allowed =>
           "symbolic links are not allowed for repository inputs",
         when Diagnostics.Input_Open_Failed =>
           "repository input cannot be opened",
         when Diagnostics.Input_Identity_Changed_While_Opening =>
           "repository input identity changed while opening",
         when Diagnostics.File_Changed_While_Reading =>
           "repository file changed while reading");

   procedure Run is
   begin
      for Item in Diagnostics.Reason loop
         declare
            Identity_Matches : Boolean := False;
         begin
            begin
               Diagnostics.Raise_Input (Item);
            exception
               when E : others =>
                  Identity_Matches :=
                    Diagnostics.Is_Repository_Error (E)
                      and then Diagnostics.Reason_Of (E) = Item
                      and then Diagnostics.Rendered_Message (E) =
                        Expected_Message (Item);
            end;
            Check.Check
              (Identity_Matches,
               "repository diagnostic reason has a stable identity");
         end;
         Check.Check
           (Diagnostics.Message (Item) = Expected_Message (Item),
            "repository diagnostic message is stable");
      end loop;
      declare
         Kind : Ada.Directories.File_Kind;
         pragma Unreferenced (Kind);
         Matched : Boolean := False;
      begin
         begin
            Kind := Discovery_IO.Kind
              ("giflib-definitely-missing-discovery-entry",
               Diagnostics.Entry_Identity_Changed_During_Discovery);
         exception
            when E : others =>
               Matched := Diagnostics.Is_Repository_Error (E)
                 and then Diagnostics.Reason_Of (E) =
                   Diagnostics.Entry_Identity_Changed_During_Discovery;
         end;
         Check.Check
           (Matched, "discovery filesystem failures use stable diagnostics");
      end;
      declare
         Cleanup : aliased Searches.Cleanup_Status :=
           Searches.Cleanup_Complete;
         Search : Searches.Search (Cleanup'Access);
         Item : Ada.Directories.Directory_Entry_Type;
         Matched : Boolean := False;
      begin
         begin
            Searches.Next_Entry (Search, Item);
         exception
            when Searches.Search_Failed =>
               Matched := True;
         end;
         Check.Check
           (Matched, "invalid search status is translated at the search boundary");
      end;
   end Run;
end Giflib_Tooling.Repository_Diagnostic_Tests;
