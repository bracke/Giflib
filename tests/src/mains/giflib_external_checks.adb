with Ada.Command_Line;
with Ada.Directories;
with Ada.Text_IO;

with Giflib.Streams;
with Giflib_FFmpeg_Oracle;
with Giflib_ImageMagick_Oracle;
with Giflib_Oracle_Assertions;
with Giflib_Oracle_Expectations;
with Giflib_Oracle_Process;
with Project_Tools.Files;
with Project_Tools.Processes;
with Project_Tools.Release_Checks;
with Project_Tools.Test_Fixtures;

procedure Giflib_External_Checks is
   Still_Expected : constant Giflib.Streams.Byte_Array :=
     [255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255,
      0, 0, 255, 255, 0, 255, 0, 255, 255, 0, 0, 255];
   Animation_Expected : constant Giflib.Streams.Byte_Array :=
     [255, 0, 0, 255, 0, 255, 0, 255,
      0, 0, 255, 255, 0, 255, 0, 255];
begin
   if Ada.Command_Line.Argument_Count > 1 then
      Project_Tools.Release_Checks.Fail
        ("usage: giflib_external_checks [artifact-directory]");
   end if;

   declare
      package Files renames Project_Tools.Files;
      package Processes renames Project_Tools.Processes;

      Root : constant String := Files.Find_Root_Upward
        (Ada.Directories.Current_Directory, "giflib.gpr");
      Artifact_Directory : constant String :=
        (if Ada.Command_Line.Argument_Count = 1
         then Ada.Command_Line.Argument (1)
         else Files.Join (Root, "tests/artifacts"));
      Fixture_Directory : constant String :=
        Files.Join (Root, "tests/fixtures");
      Convert : constant String := Processes.Locate_Command ("convert");
      Identify : constant String := Processes.Locate_Command ("identify");
      FFmpeg : constant String := Processes.Locate_Command ("ffmpeg");
      FFprobe : constant String := Processes.Locate_Command ("ffprobe");
      Convert_Runner : constant Giflib_Oracle_Process.Runner :=
        Giflib_Oracle_Process.Create (Root, Convert);
      Identify_Runner : constant Giflib_Oracle_Process.Runner :=
        Giflib_Oracle_Process.Create (Root, Identify);
      FFmpeg_Runner : constant Giflib_Oracle_Process.Runner :=
        Giflib_Oracle_Process.Create (Root, FFmpeg);
      FFprobe_Runner : constant Giflib_Oracle_Process.Runner :=
        Giflib_Oracle_Process.Create (Root, FFprobe);
      Still : constant String :=
        Files.Join (Artifact_Directory, "giflib-still.gif");
      Animation : constant String :=
        Files.Join (Artifact_Directory, "giflib-animation.gif");
      Truecolor : constant String :=
        Files.Join (Artifact_Directory, "giflib-truecolor.gif");
   begin
      if Root = "" then
         Project_Tools.Release_Checks.Fail
           ("giflib_external_checks: run from within the giflib source tree");
      end if;
      Processes.Require_Command
        ("convert", "giflib_external_checks: convert is required");
      Processes.Require_Command
        ("identify", "giflib_external_checks: identify is required");
      Processes.Require_Command
        ("ffmpeg", "giflib_external_checks: ffmpeg is required");
      Processes.Require_Command
        ("ffprobe", "giflib_external_checks: ffprobe is required");

      declare
         Scratch : constant String :=
           Project_Tools.Test_Fixtures.Fresh_Temp_Dir
             ("giflib-external-checks");

         function Temporary (Tag : String) return String is
           (Files.Join (Scratch, Tag & ".rgba"));

         procedure Check_Decode
           (GIF, Tag, Description : String;
            Expected : Giflib.Streams.Byte_Array)
         is
            IM : constant String := Temporary ("im-" & Tag);
            FF : constant String := Temporary ("ff-" & Tag);
         begin
            Giflib_ImageMagick_Oracle.Decode
              (Convert_Runner, GIF, IM, Description & " decode");
            Giflib_FFmpeg_Oracle.Decode
              (FFmpeg_Runner, GIF, FF, Description & " decode");
            Giflib_Oracle_Assertions.Exact_RGBA
              (IM, Expected, "ImageMagick " & Description);
            Giflib_Oracle_Assertions.Exact_RGBA
              (FF, Expected, "FFmpeg " & Description);
         end Check_Decode;
      begin
         Giflib_Oracle_Expectations.Generated_Metadata
           (Giflib_ImageMagick_Oracle.Generated_Metadata
              (Identify_Runner, Still, Animation, Truecolor),
            Giflib_ImageMagick_Oracle.Animation_Details
              (Identify_Runner, Animation),
            Giflib_FFmpeg_Oracle.Generated_Metadata
              (FFprobe_Runner, Animation));
         Check_Decode (Still, "still", "still", Still_Expected);
         Check_Decode
           (Animation, "animation", "animation", Animation_Expected);
         declare
            IM : constant String := Temporary ("im-truecolor");
            FF : constant String := Temporary ("ff-truecolor");
         begin
            Giflib_ImageMagick_Oracle.Decode
              (Convert_Runner, Truecolor, IM, "truecolor decode");
            Giflib_FFmpeg_Oracle.Decode
              (FFmpeg_Runner, Truecolor, FF, "truecolor decode");
            Giflib_Oracle_Expectations.Truecolor_Quality
              (IM, "ImageMagick truecolor");
            Giflib_Oracle_Expectations.Truecolor_Quality
              (FF, "FFmpeg truecolor");
         end;
         Giflib_Oracle_Expectations.Independent_Metadata
           (Giflib_ImageMagick_Oracle.Independent_Metadata
              (Identify_Runner, Fixture_Directory),
            Giflib_FFmpeg_Oracle.Independent_Frames
              (FFprobe_Runner, Fixture_Directory),
            Giflib_FFmpeg_Oracle.Large_Animation_Metadata
              (FFprobe_Runner, Fixture_Directory));
         Ada.Text_IO.Put_Line
           (Giflib_ImageMagick_Oracle.Version (Identify_Runner));
         Ada.Text_IO.Put_Line
           (Giflib_FFmpeg_Oracle.Version (FFmpeg_Runner));
         Project_Tools.Test_Fixtures.Cleanup (Scratch);
         Ada.Text_IO.Put_Line ("Ada external-oracle checks passed");
      exception
         when others =>
            Project_Tools.Test_Fixtures.Cleanup (Scratch);
            raise;
      end;
   end;
end Giflib_External_Checks;
