with Ada.Directories;

with Project_Tools.Files;
with Project_Tools.Test_Fixtures;

with Giflib_Tooling.Repository_Diagnostics;
with Giflib_Tooling.Repository_Files.Testing;
with Giflib_Tooling.Repository_Handles;
with Giflib_Tooling.Repository_Identity;
with Giflib_Tooling.Repository_Race_Support;
with Giflib_Tooling.Repository_Test_Support;
with Giflib_Tooling.Self_Test_Support;

package body Giflib_Tooling.Repository_Read_Race_Tests is
   package Check renames Giflib_Tooling.Self_Test_Support;
   package Diagnostics renames Giflib_Tooling.Repository_Diagnostics;
   package Files renames Project_Tools.Files;
   package Fixtures renames Project_Tools.Test_Fixtures;
   package Identity renames Giflib_Tooling.Repository_Identity;
   package Race_Support renames Giflib_Tooling.Repository_Race_Support;
   package Repository_Files renames Giflib_Tooling.Repository_Files;
   package Repository_Testing renames
     Giflib_Tooling.Repository_Files.Testing;
   package Support renames Giflib_Tooling.Repository_Test_Support;
   use type Identity.Verification_Status;

   procedure Run is
      procedure Exercise
        (Root : String; Inside : String; Link_Command : String)
      is
         pragma Unreferenced (Root);
         Link : constant String := Files.Join (Inside, "link.txt");
         Race : constant String := Files.Join (Inside, "race.txt");
         Race_Saved : constant String :=
           Files.Join (Inside, "race-saved.txt");
         Race_Link : constant String := Files.Join (Inside, "race-link.txt");
         Regular : constant String := Files.Join (Inside, "regular.txt");
         Regular_Saved : constant String :=
           Files.Join (Inside, "regular-saved.txt");
         Replacement : constant String :=
           Files.Join (Inside, "replacement.txt");
         In_Place : constant String := Files.Join (Inside, "in-place.txt");

         procedure Replace_Link is
         begin
            Ada.Directories.Rename (Race, Race_Saved);
            Ada.Directories.Rename (Race_Link, Race);
         end Replace_Link;

         procedure Replace_Regular is
         begin
            Ada.Directories.Rename (Regular, Regular_Saved);
            Ada.Directories.Rename (Replacement, Regular);
         end Replace_Regular;

         procedure Modify_In_Place is
         begin
            Fixtures.Write_Text_File (In_Place, "bbbbbb");
         end Modify_In_Place;

         procedure Read_Link is
            Ignored : constant String :=
              Repository_Files.Read_Bounded_Within (Inside, Link, 100);
            pragma Unreferenced (Ignored);
         begin
            null;
         end Read_Link;

         procedure Read_Replaced_Link is
            Ignored : constant String :=
              Repository_Testing.Read_Bounded_Within_With_Hook
                (Inside, Race, 100, Replace_Link'Access);
            pragma Unreferenced (Ignored);
         begin
            null;
         end Read_Replaced_Link;

         procedure Read_Replaced_File is
            Ignored : constant String :=
              Repository_Testing.Read_Bounded_Within_With_Hook
                (Inside, Regular, 100, Replace_Regular'Access);
            pragma Unreferenced (Ignored);
         begin
            null;
         end Read_Replaced_File;

         procedure Read_Modified_File is
            Ignored : constant String :=
              Repository_Testing.Read_Bounded_Within_With_Read_Hook
                (Inside, In_Place, 100, Modify_In_Place'Access);
            pragma Unreferenced (Ignored);
         begin
            null;
         end Read_Modified_File;

         procedure Expect
           (Action : not null access procedure;
            Reason : Diagnostics.Reason;
            Message : String)
         is
            Matched : Boolean;
         begin
            Support.Expect_Reason (Action, Reason, Matched);
            Check.Check (Matched, Message);
         end Expect;
      begin
         declare
            Closed : Giflib_Tooling.Repository_Handles.Owner;
         begin
            Check.Check
              (Identity.Opened_Directory_Status
                 (Closed, Identity.Canonical_Path (Inside)) =
                   Identity.Identity_Mismatch,
               "repository directory identity requires an open descriptor");
         end;
         if Link_Command = "" then
            Check.Skip ("symlink replacement regressions require ln");
            return;
         end if;
         Race_Support.Create_Link
           (Inside, Link_Command, "../outside.txt", "link.txt");
         Expect
           (Read_Link'Access, Diagnostics.Symbolic_Link_Not_Allowed,
            "repository reads reject symbolic targets");

         Fixtures.Write_Text_File (Race, "inside");
         Race_Support.Create_Link
           (Inside, Link_Command, "../outside.txt", "race-link.txt");
         Expect
           (Read_Replaced_Link'Access,
            Diagnostics.Input_Identity_Changed_While_Opening,
            "repository reads reject replacement after descriptor acquisition");

         Fixtures.Write_Text_File (Regular, "inside");
         Fixtures.Write_Text_File (Replacement, "replacement");
         Expect
           (Read_Replaced_File'Access,
            Diagnostics.Input_Identity_Changed_While_Opening,
            "repository reads reject same-path regular replacement");

         Fixtures.Write_Text_File (In_Place, "aaaaaa");
         Expect
           (Read_Modified_File'Access, Diagnostics.File_Changed_While_Reading,
            "repository reads reject same-length in-place changes");
      end Exercise;
   begin
      Race_Support.With_Fixture
        ("giflib-repository-read-races", Exercise'Access);
   end Run;
end Giflib_Tooling.Repository_Read_Race_Tests;
