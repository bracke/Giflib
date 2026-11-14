with Ada.Directories;

with Project_Tools.Files;

with Giflib_Tooling.Repository_Diagnostics;
with Giflib_Tooling.Repository_Files;
with Giflib_Tooling.Repository_Handles;
with Giflib_Tooling.Repository_Snapshots;
with Giflib_Tooling.Repository_Test_Support;
with Giflib_Tooling.Self_Test_Support;
with Giflib_Tooling.Source_Limits;

package body Giflib_Tooling.Repository_Limit_Tests is
   use type Giflib_Tooling.Repository_Diagnostics.Reason;
   package Check renames Giflib_Tooling.Self_Test_Support;
   package Diagnostics renames Giflib_Tooling.Repository_Diagnostics;
   package Files renames Project_Tools.Files;
   package Limits renames Giflib_Tooling.Source_Limits;
   package Repository_Files renames Giflib_Tooling.Repository_Files;
   package Support renames Giflib_Tooling.Repository_Test_Support;

   procedure Run is
      Repository_Root : constant String :=
        Files.Find_Root_Upward
          (Ada.Directories.Current_Directory, "giflib.gpr");
      Discovery_Entry_Limit_Rejected : Boolean := False;
      Discovery_File_Limit_Rejected : Boolean := False;
      Discovery_Depth_Limit_Rejected : Boolean := False;
      Bounded_Read_Rejected : Boolean := False;
      Escaped_Read_Rejected : Boolean := False;
      Snapshot_Storage_Rejected : Boolean := False;

      procedure Ignore
        (Path : String;
         Name : String;
         File : Giflib_Tooling.Repository_Handles.Owner) is
         pragma Unreferenced (Path, Name, File);
      begin
         null;
      end Ignore;

      procedure Walk_With_Entry_Limit is
      begin
         Repository_Files.Walk_Opened
           (Files.Join (Repository_Root, "tests/src"), Ignore'Access,
            (Maximum_Discovery_Entries => 0, others => <>));
      end Walk_With_Entry_Limit;

      procedure Walk_With_File_Limit is
      begin
         Repository_Files.Walk_Opened
           (Files.Join (Repository_Root, "tests/src"), Ignore'Access,
            (Maximum_Source_Files => 0, others => <>));
      end Walk_With_File_Limit;

      procedure Walk_With_Depth_Limit is
      begin
         Repository_Files.Walk_Opened
           (Files.Join (Repository_Root, "tests/src"), Ignore'Access,
            (Maximum_Directory_Depth => 0, others => <>));
      end Walk_With_Depth_Limit;

      procedure Read_With_Length_Limit is
         Ignored : constant String := Repository_Files.Read_Bounded
           (Files.Join (Repository_Root, "giflib.gpr"), 0);
         pragma Unreferenced (Ignored);
      begin
         null;
      end Read_With_Length_Limit;

      procedure Read_Outside_Root is
         Ignored : constant String := Repository_Files.Read_Bounded_Within
           (Files.Join (Repository_Root, "tests"),
            Files.Join (Repository_Root, "giflib.gpr"),
            Limits.Default_Analysis_Limits.Parsing.Maximum_Source_Length);
         pragma Unreferenced (Ignored);
      begin
         null;
      end Read_Outside_Root;
   begin
      Support.Expect_Reason
        (Walk_With_Entry_Limit'Access,
         Diagnostics.Discovery_Entry_Limit_Exceeded,
         Discovery_Entry_Limit_Rejected);
      Support.Expect_Reason
        (Walk_With_File_Limit'Access, Diagnostics.Source_File_Limit_Exceeded,
         Discovery_File_Limit_Rejected);
      Support.Expect_Reason
        (Walk_With_Depth_Limit'Access,
         Diagnostics.Directory_Depth_Limit_Exceeded,
         Discovery_Depth_Limit_Rejected);
      Support.Expect_Reason
        (Read_With_Length_Limit'Access,
         Diagnostics.File_Length_Limit_Exceeded, Bounded_Read_Rejected);
      Support.Expect_Reason
        (Read_Outside_Root'Access,
         Diagnostics.Input_Identity_Changed_While_Opening,
         Escaped_Read_Rejected);
      begin
         declare
            Ignored : constant Giflib_Tooling.Repository_Snapshots.Snapshot :=
              Giflib_Tooling.Repository_Snapshots.Build
                (Repository_Root,
                 Giflib_Tooling.Repository_Snapshots.Source_Only,
                 (Snapshot =>
                    (Maximum_Storage_Units => 1, others => <>),
                  others => <>));
            pragma Unreferenced (Ignored);
         begin
            null;
         end;
      exception
         when Input_Error =>
            Snapshot_Storage_Rejected := True;
      end;
      Check.Check
        (Discovery_Entry_Limit_Rejected
         and then Discovery_File_Limit_Rejected
         and then Discovery_Depth_Limit_Rejected
         and then Bounded_Read_Rejected
         and then Escaped_Read_Rejected
         and then Snapshot_Storage_Rejected,
         "repository traversal enforces every configured resource limit");
   end Run;
end Giflib_Tooling.Repository_Limit_Tests;
