with Ada.Directories;

with Project_Tools.Files;
with Project_Tools.Test_Fixtures;

with Giflib_Tooling.Repository_Diagnostics;
with Giflib_Tooling.Repository_Files;
with Giflib_Tooling.Repository_Files.Testing;
with Giflib_Tooling.Repository_Handles;
with Giflib_Tooling.Repository_Race_Support;
with Giflib_Tooling.Repository_Test_Support;
with Giflib_Tooling.Self_Test_Support;

package body Giflib_Tooling.Repository_Traversal_Race_Tests is
   package Check renames Giflib_Tooling.Self_Test_Support;
   package Diagnostics renames Giflib_Tooling.Repository_Diagnostics;
   package Files renames Project_Tools.Files;
   package Fixtures renames Project_Tools.Test_Fixtures;
   package Race_Support renames Giflib_Tooling.Repository_Race_Support;
   package Repository_Files renames Giflib_Tooling.Repository_Files;
   package Repository_Testing renames
     Giflib_Tooling.Repository_Files.Testing;
   package Support renames Giflib_Tooling.Repository_Test_Support;

   procedure Run is
      procedure Exercise
        (Root : String; Inside : String; Link_Command : String)
      is
         Missing : constant String := Files.Join (Root, "missing");
         Target : constant String := Files.Join (Inside, "walk.txt");
         Saved : constant String := Files.Join (Inside, "walk-saved.txt");
         Link : constant String := Files.Join (Inside, "zz-walk-link.txt");
         Regular : constant String := Files.Join (Inside, "walk-regular.txt");
         Regular_Saved : constant String :=
           Files.Join (Inside, "walk-regular-saved.txt");
         Replacement : constant String :=
           Files.Join (Inside, "walk-replacement.txt");
         Directory : constant String :=
           Files.Join (Inside, "walk-directory");
         Directory_Saved : constant String :=
           Files.Join (Inside, "walk-directory-saved");
         Directory_Target : constant String :=
           Files.Join (Directory, "child.txt");
         Link_Replaced : Boolean := False;
         Regular_Replaced : Boolean := False;
         Directory_Replaced : Boolean := False;

         procedure Ignore
           (Path : String;
            Name : String;
            File : Giflib_Tooling.Repository_Handles.Owner) is
            pragma Unreferenced (Path, Name, File);
         begin
            null;
         end Ignore;

         procedure Replace_Link (Path : String) is
         begin
            if Path = Target then
               Link_Replaced := True;
               Ada.Directories.Rename (Target, Saved);
               Ada.Directories.Rename (Link, Target);
            end if;
         end Replace_Link;

         procedure Replace_Regular (Path : String) is
         begin
            if Path = Regular then
               Regular_Replaced := True;
               Ada.Directories.Rename (Regular, Regular_Saved);
               Ada.Directories.Rename (Replacement, Regular);
            end if;
         end Replace_Regular;

         procedure Replace_Directory (Path : String) is
         begin
            if Path = Directory_Target then
               Directory_Replaced := True;
               Ada.Directories.Rename (Directory, Directory_Saved);
               Fixtures.Make_Directory (Directory);
            end if;
         end Replace_Directory;

         procedure Walk_Missing is
         begin
            Repository_Files.Walk_Opened (Missing, Ignore'Access);
         end Walk_Missing;

         procedure Walk_Link is
         begin
            Repository_Testing.Walk_With_Hook
              (Inside, Ignore'Access, Before_Inspect => Replace_Link'Access);
         end Walk_Link;

         procedure Walk_Regular is
         begin
            Repository_Testing.Walk_With_Hook
              (Inside, Ignore'Access,
               Before_Inspect => Replace_Regular'Access);
         end Walk_Regular;

         procedure Walk_Directory is
         begin
            Repository_Testing.Walk_With_Hook
              (Inside, Ignore'Access,
               Before_Inspect => Replace_Directory'Access);
         end Walk_Directory;

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
         Expect
           (Walk_Missing'Access,
            Diagnostics.Root_Canonicalization_Failed,
            "repository discovery rejects a missing root");
         if Link_Command = "" then
            Check.Skip ("symlink replacement regressions require ln");
            return;
         end if;

         Fixtures.Write_Text_File (Target, "inside");
         Race_Support.Create_Link
           (Inside, Link_Command, "../outside.txt", "zz-walk-link.txt");
         Expect
           (Walk_Link'Access,
            Diagnostics.Entry_Identity_Changed_During_Discovery,
            "repository discovery rejects entry replacement");
         Check.Check (Link_Replaced, "entry replacement hook was exercised");
         Ada.Directories.Delete_File (Target);
         Ada.Directories.Rename (Saved, Target);

         Fixtures.Write_Text_File (Regular, "inside");
         Fixtures.Write_Text_File (Replacement, "replacement");
         Expect
           (Walk_Regular'Access,
            Diagnostics.Entry_Identity_Changed_During_Discovery,
            "repository discovery rejects same-path regular replacement");
         Check.Check
           (Regular_Replaced,
            "regular entry replacement hook was exercised");

         Fixtures.Make_Directory (Directory);
         Fixtures.Write_Text_File (Directory_Target, "inside");
         Expect
           (Walk_Directory'Access,
            Diagnostics.Directory_Changed_During_Discovery,
            "repository discovery rejects directory replacement");
         Check.Check
           (Directory_Replaced,
            "directory replacement hook was exercised");
      end Exercise;
   begin
      Race_Support.With_Fixture
        ("giflib-repository-traversal-races", Exercise'Access);
   end Run;
end Giflib_Tooling.Repository_Traversal_Race_Tests;
