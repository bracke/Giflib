with Ada.Directories;
with Ada.Strings.Unbounded;

with Project_Tools.Files;
with Project_Tools.Test_Fixtures;

with Giflib_Tooling.Repository_Files;
with Giflib_Tooling.Repository_Handles;
with Giflib_Tooling.Repository_Race_Support;
with Giflib_Tooling.Repository_Snapshots;
with Giflib_Tooling.Self_Test_Support;

package body Giflib_Tooling.Repository_Snapshot_Race_Tests is
   package Check renames Giflib_Tooling.Self_Test_Support;
   package Files renames Project_Tools.Files;
   package Fixtures renames Project_Tools.Test_Fixtures;
   package Race_Support renames Giflib_Tooling.Repository_Race_Support;
   package Repository_Files renames Giflib_Tooling.Repository_Files;
   package Snapshots renames Giflib_Tooling.Repository_Snapshots;
   package Unbounded renames Ada.Strings.Unbounded;

   procedure Run is
      procedure Exercise
        (Root : String; Inside : String; Link_Command : String)
      is
         Descriptor_Target : constant String :=
           Files.Join (Inside, "descriptor.txt");
         Descriptor_Saved : constant String :=
           Files.Join (Inside, "descriptor-saved.txt");
         Descriptor_Replacement : constant String :=
           Files.Join (Inside, "descriptor-replacement.txt");
         Descriptor_Replaced : Boolean := False;
         Descriptor_Text : Unbounded.Unbounded_String;

         procedure Read_While_Replaced
           (Path : String;
            Name : String;
            File : Giflib_Tooling.Repository_Handles.Owner)
         is
            pragma Unreferenced (Name);
         begin
            if Path = Descriptor_Target then
               Descriptor_Replaced := True;
               Ada.Directories.Rename
                 (Descriptor_Target, Descriptor_Saved);
               Ada.Directories.Rename
                 (Descriptor_Replacement, Descriptor_Target);
               begin
                  Descriptor_Text := Unbounded.To_Unbounded_String
                    (Repository_Files.Read_Pinned_Bounded (File, 100));
                  Ada.Directories.Rename
                    (Descriptor_Target, Descriptor_Replacement);
                  Ada.Directories.Rename
                    (Descriptor_Saved, Descriptor_Target);
               exception
                  when others =>
                     if Ada.Directories.Exists (Descriptor_Target) then
                        Ada.Directories.Rename
                          (Descriptor_Target, Descriptor_Replacement);
                     end if;
                     if Ada.Directories.Exists (Descriptor_Saved) then
                        Ada.Directories.Rename
                          (Descriptor_Saved, Descriptor_Target);
                     end if;
                     raise;
               end;
            end if;
         end Read_While_Replaced;
      begin
         Fixtures.Write_Text_File
           (Descriptor_Target, "descriptor-original");
         Fixtures.Write_Text_File
           (Descriptor_Replacement, "descriptor-replacement");
         Repository_Files.Walk_Opened
           (Inside, Read_While_Replaced'Access);
         Check.Check
           (Descriptor_Replaced
            and then Unbounded.To_String (Descriptor_Text) =
              "descriptor-original",
            "repository callbacks read the verified open descriptor");

         if Link_Command = "" then
            Check.Skip ("snapshot redirection regression requires ln");
            return;
         end if;
         declare
            Snapshot_Root : constant String := Files.Join (Root, "snapshot");
            Snapshot_Source : constant String :=
              Files.Join (Snapshot_Root, "src");
            Snapshot_Target : constant String :=
              Files.Join (Snapshot_Source, "a.ads");
            Snapshot_Saved : constant String :=
              Files.Join (Snapshot_Source, "a-saved.ads");
            Snapshot_Replacement : constant String :=
              Files.Join (Snapshot_Source, "b.ads");
         begin
            Fixtures.Make_Directory (Snapshot_Source);
            Fixtures.Write_Text_File
              (Snapshot_Target, "snapshot-original");
            Fixtures.Write_Text_File
              (Snapshot_Replacement, "snapshot-replacement");
            declare
               Repository : constant Snapshots.Snapshot :=
                 Snapshots.Build (Snapshot_Root, Snapshots.Source_Only);
            begin
               Ada.Directories.Rename (Snapshot_Target, Snapshot_Saved);
               Race_Support.Create_Link
                 (Snapshot_Source, Link_Command, "b.ads", "a.ads");
               declare
                  Matches : Boolean := False;
                  procedure Inspect (Text : String) is
                  begin
                     Matches := Text = "snapshot-original";
                  end Inspect;
               begin
                  Snapshots.Inspect_Text
                    (Repository, Snapshot_Target, Inspect'Access);
                  Check.Check
                    (Matches,
                     "snapshot lookup cannot be redirected after capture");
               end;
            end;
         end;
      end Exercise;
   begin
      Race_Support.With_Fixture
        ("giflib-repository-snapshot-races", Exercise'Access);
   end Run;
end Giflib_Tooling.Repository_Snapshot_Race_Tests;
