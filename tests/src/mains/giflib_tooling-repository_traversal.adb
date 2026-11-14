with Ada.Directories;
with Ada.Strings.Unbounded;
with Project_Tools.Files;

with Giflib_Tooling.Repository_Identity;
with Giflib_Tooling.Repository_Diagnostics;
with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Repository_Discovery_IO;

package body Giflib_Tooling.Repository_Traversal is
   use Ada.Strings.Unbounded;
   use type Ada.Directories.File_Kind;
   package Files renames Project_Tools.Files;
   package Identity renames Giflib_Tooling.Repository_Identity;
   package Diagnostics renames Giflib_Tooling.Repository_Diagnostics;
   package Names renames Giflib_Tooling.Name_Collections;
   package Handles renames Giflib_Tooling.Repository_Handles;
   package Searches renames Giflib_Tooling.Repository_Searches;
   package Discovery_IO renames Giflib_Tooling.Repository_Discovery_IO;
   use type Identity.Verification_Status;
   use type Searches.Cleanup_Status;

   function Less (Left, Right : Unbounded_String) return Boolean is
     (To_String (Left) < To_String (Right));

   package Name_Sorting is new Names.Name_Vectors.Generic_Sorting
     ("<" => Less);

   type Traversal_State is record
      Canonical_Root : Unbounded_String;
      Discovery : Giflib_Tooling.Source_Limits.Discovery_Limits;
      Maximum_Source_Length : Natural;
      Entry_Count : Natural := 0;
      File_Count : Natural := 0;
      Search_Cleanup : aliased Searches.Cleanup_Status :=
        Searches.Cleanup_Complete;
   end record;

   function Discover_Root (Root : String) return String is
   begin
      if not Discovery_IO.Exists
        (Root, Diagnostics.Root_Canonicalization_Failed)
      then
         Diagnostics.Raise_Input
           (Diagnostics.Root_Canonicalization_Failed);
      end if;
      declare
         Result : constant String := Discovery_IO.Canonical_Path
           (Root, Diagnostics.Root_Canonicalization_Failed);
      begin
         if Result = "" then
            Diagnostics.Raise_Input
              (Diagnostics.Root_Canonicalization_Failed);
         end if;
         return Result;
      end;
   end Discover_Root;

   procedure Visit
     (State : in out Traversal_State;
      Directory : String;
      Depth : Natural;
      Process : not null access procedure
        (Path : String; Name : String; File : Handles.Owner);
      Before_Inspect : access procedure (Path : String)) is separate;

   procedure Walk
     (Root : String;
      Process : not null access procedure
        (Path : String;
         Name : String;
         File : Handles.Owner);
      Discovery : Giflib_Tooling.Source_Limits.Discovery_Limits;
      Maximum_Source_Length : Natural;
      Before_Inspect : access procedure (Path : String);
      Cleanup_State : access Searches.Cleanup_Status := null)
   is
      State : Traversal_State :=
        (Canonical_Root => To_Unbounded_String (Discover_Root (Root)),
         Discovery => Discovery,
         Maximum_Source_Length => Maximum_Source_Length,
         others => <>);

      procedure Observe_Cleanup is
      begin
         if State.Search_Cleanup = Searches.Cleanup_Failed
           and then Cleanup_State /= null
         then
            Cleanup_State.all := Searches.Cleanup_Failed;
         end if;
      end Observe_Cleanup;
   begin
      Visit
        (State, To_String (State.Canonical_Root), 0, Process,
         Before_Inspect);
      if State.Search_Cleanup = Searches.Cleanup_Failed then
         Observe_Cleanup;
         Diagnostics.Raise_Input
           (Diagnostics.Directory_Search_Cleanup_Failed);
      end if;
   exception
      when others =>
         --  Controlled Search objects have finalized before this handler.
         --  Preserve the primary exception while exposing cleanup failure.
         Observe_Cleanup;
         raise;
   end Walk;
end Giflib_Tooling.Repository_Traversal;
