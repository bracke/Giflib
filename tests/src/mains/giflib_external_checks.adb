with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Giflib;
with Giflib.Streams;
with Project_Tools.Files;
with Project_Tools.Processes;
with Project_Tools.Release_Checks;
with Project_Tools.Test_Fixtures;
with Project_Tools.Text;

procedure Giflib_External_Checks is
   package Files renames Project_Tools.Files;
   package Processes renames Project_Tools.Processes;
   use type Giflib.Byte;

   Root : constant String :=
     Files.Find_Root_Upward (Ada.Directories.Current_Directory, "giflib.gpr");
   Artifact_Directory : constant String :=
     (if Ada.Command_Line.Argument_Count >= 1
      then Ada.Command_Line.Argument (1)
      else Files.Join (Root, "tests/artifacts"));
   Fixture_Directory : constant String := Files.Join (Root, "tests/fixtures");
   Scratch : constant String :=
     Project_Tools.Test_Fixtures.Fresh_Temp_Dir ("giflib-external-checks");

   Convert  : constant String := Processes.Locate_Command ("convert");
   Identify : constant String := Processes.Locate_Command ("identify");
   FFmpeg   : constant String := Processes.Locate_Command ("ffmpeg");
   FFprobe  : constant String := Processes.Locate_Command ("ffprobe");

   procedure Require (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Project_Tools.Release_Checks.Fail ("giflib_external_checks: " & Message);
      end if;
   end Require;

   function Capture
     (Program   : String;
      Args      : Processes.Argument_Vectors.Vector;
      Operation : String) return String
   is
      Output : Ada.Strings.Unbounded.Unbounded_String;
   begin
      Processes.Run
        (Operation, Root, Program, Args, Output, Quiet => True);
      return Ada.Strings.Unbounded.To_String (Output);
   end Capture;

   function Temporary (Tag : String) return String is
     (Files.Join (Scratch, Tag & ".rgba"));

   procedure Decode_With_ImageMagick (GIF, Raw, Operation : String) is
   begin
      Processes.Run
        ("ImageMagick " & Operation,
         Root,
         Convert,
         Processes.Arguments
           ([Processes.Argument (GIF), Processes.Argument ("-coalesce"),
             Processes.Argument ("-depth"), Processes.Argument ("8"),
             Processes.Argument ("rgba:" & Raw)]),
         Quiet => True);
   end Decode_With_ImageMagick;

   procedure Decode_With_FFmpeg (GIF, Raw, Operation : String) is
   begin
      Processes.Run
        ("FFmpeg " & Operation,
         Root,
         FFmpeg,
         Processes.Arguments
           ([Processes.Argument ("-y"), Processes.Argument ("-v"),
             Processes.Argument ("error"), Processes.Argument ("-i"),
             Processes.Argument (GIF), Processes.Argument ("-vsync"),
             Processes.Argument ("0"), Processes.Argument ("-f"),
             Processes.Argument ("rawvideo"), Processes.Argument ("-pix_fmt"),
             Processes.Argument ("rgba"), Processes.Argument (Raw)]),
         Quiet => True);
   end Decode_With_FFmpeg;

   procedure Check_Exact_RGBA
     (Path        : String;
      Expected    : Giflib.Streams.Byte_Array;
      Description : String)
   is
      Raw : constant String := Files.Read_Raw_File (Path);
   begin
      Require (Raw'Length = Expected'Length, Description & " byte count changed");
      for I in Expected'Range loop
         Require
           (Giflib.Byte (Character'Pos (Raw (Raw'First + I - Expected'First))) = Expected (I),
            Description & " pixel mismatch at byte" & Natural'Image (I - Expected'First));
      end loop;
   end Check_Exact_RGBA;

   procedure Check_Truecolor_Quality (Path, Description : String) is
      Raw : constant String := Files.Read_Raw_File (Path);
      Error_Sum : Long_Long_Integer := 0;
      Position : Natural := Raw'First;
   begin
      Require (Raw'Length = 17 * 17 * 4, Description & " dimensions changed");
      for Y in 0 .. 16 loop
         for X in 0 .. 16 loop
            declare
               Expected_R : constant Long_Long_Integer := Long_Long_Integer (X * 15);
               Expected_G : constant Long_Long_Integer := Long_Long_Integer (Y * 15);
               Expected_B : constant Long_Long_Integer := Long_Long_Integer ((X * 17 + Y) mod 256);
            begin
               Error_Sum := Error_Sum
                 + (Long_Long_Integer (Character'Pos (Raw (Position))) - Expected_R) ** 2
                 + (Long_Long_Integer (Character'Pos (Raw (Position + 1))) - Expected_G) ** 2
                 + (Long_Long_Integer (Character'Pos (Raw (Position + 2))) - Expected_B) ** 2;
               Require
                 (Character'Pos (Raw (Position + 3)) = 255,
                  Description & " introduced unexpected transparency");
               Position := Position + 4;
            end;
         end loop;
      end loop;
      Require
        (Error_Sum / Long_Long_Integer (17 * 17 * 3) < 5_000,
         Description & " exceeded the RGB mean-square threshold");
   end Check_Truecolor_Quality;

   Still_Expected : constant Giflib.Streams.Byte_Array :=
     [255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255,
      0, 0, 255, 255, 0, 255, 0, 255, 255, 0, 0, 255];
   Animation_Expected : constant Giflib.Streams.Byte_Array :=
     [255, 0, 0, 255, 0, 255, 0, 255,
      0, 0, 255, 255, 0, 255, 0, 255];

   Still : constant String := Files.Join (Artifact_Directory, "giflib-still.gif");
   Animation : constant String := Files.Join (Artifact_Directory, "giflib-animation.gif");
   Truecolor : constant String := Files.Join (Artifact_Directory, "giflib-truecolor.gif");
begin
   if Root = "" then
      Project_Tools.Release_Checks.Fail
        ("giflib_external_checks: run from within the giflib source tree");
   elsif Ada.Command_Line.Argument_Count > 1 then
      Project_Tools.Release_Checks.Fail
        ("usage: giflib_external_checks [artifact-directory]");
   end if;
   Processes.Require_Command ("convert", "giflib_external_checks: convert is required");
   Processes.Require_Command ("identify", "giflib_external_checks: identify is required");
   Processes.Require_Command ("ffmpeg", "giflib_external_checks: ffmpeg is required");
   Processes.Require_Command ("ffprobe", "giflib_external_checks: ffprobe is required");

   declare
      ImageMagick_Metadata : constant String := Capture
        (Identify,
         Processes.Arguments
           ([Processes.Argument ("-format"), Processes.Argument ("%m %wx%h %n %T|"),
             Processes.Argument (Still), Processes.Argument (Animation),
             Processes.Argument (Truecolor)]),
         "ImageMagick metadata check");
      ImageMagick_Animation_Details : constant String := Capture
        (Identify,
         Processes.Arguments
           ([Processes.Argument ("-verbose"), Processes.Argument (Animation)]),
         "ImageMagick animation detail check");
      FFprobe_Metadata : constant String := Capture
        (FFprobe,
         Processes.Arguments
           ([Processes.Argument ("-v"), Processes.Argument ("error"),
             Processes.Argument ("-select_streams"), Processes.Argument ("v:0"),
             Processes.Argument ("-count_frames"), Processes.Argument ("-show_entries"),
             Processes.Argument ("stream=codec_name,width,height,nb_read_frames"),
             Processes.Argument ("-of"),
             Processes.Argument ("default=noprint_wrappers=1"),
             Processes.Argument (Animation)]),
         "FFprobe metadata check");
   begin
      Require
        (ImageMagick_Metadata =
           "GIF 3x2 1 0|GIF 2x1 2 3|GIF 1x1 2 0|GIF 17x17 1 0|",
         "ImageMagick reported incorrect generated metadata");
      Require
        (Project_Tools.Text.Line_Value
           (ImageMagick_Animation_Details, "  Iterations", ":") = "0",
         "ImageMagick reported an incorrect animation loop count");
      Require
        (Project_Tools.Text.Line_Value
           (FFprobe_Metadata, "codec_name", "=") = "gif",
         "FFprobe did not select the GIF codec");
      Require
        (Project_Tools.Text.Line_Value (FFprobe_Metadata, "width", "=") = "2"
         and then Project_Tools.Text.Line_Value
           (FFprobe_Metadata, "height", "=") = "1"
         and then Project_Tools.Text.Line_Value
           (FFprobe_Metadata, "nb_read_frames", "=") = "2",
         "FFprobe rejected animation dimensions/frame count");
   end;

   declare
      IM : constant String := Temporary ("im-still");
      FF : constant String := Temporary ("ff-still");
   begin
      Decode_With_ImageMagick (Still, IM, "still decode");
      Decode_With_FFmpeg (Still, FF, "still decode");
      Check_Exact_RGBA (IM, Still_Expected, "ImageMagick still");
      Check_Exact_RGBA (FF, Still_Expected, "FFmpeg still");
   end;
   declare
      IM : constant String := Temporary ("im-animation");
      FF : constant String := Temporary ("ff-animation");
   begin
      Decode_With_ImageMagick (Animation, IM, "animation decode");
      Decode_With_FFmpeg (Animation, FF, "animation decode");
      Check_Exact_RGBA (IM, Animation_Expected, "ImageMagick animation");
      Check_Exact_RGBA (FF, Animation_Expected, "FFmpeg animation");
   end;
   declare
      IM : constant String := Temporary ("im-truecolor");
      FF : constant String := Temporary ("ff-truecolor");
   begin
      Decode_With_ImageMagick (Truecolor, IM, "truecolor decode");
      Decode_With_FFmpeg (Truecolor, FF, "truecolor decode");
      Check_Truecolor_Quality (IM, "ImageMagick truecolor");
      Check_Truecolor_Quality (FF, "FFmpeg truecolor");
   end;

   declare
      Independent_Metadata : constant String := Capture
        (Identify,
         Processes.Arguments
           ([Processes.Argument ("-format"), Processes.Argument ("%m %wx%h %n|"),
             Processes.Argument (Files.Join (Fixture_Directory, "external/docbook-tip.gif")),
             Processes.Argument (Files.Join (Fixture_Directory, "external/docbook-warning.gif")),
             Processes.Argument
               (Files.Join (Fixture_Directory, "generated/imagemagick-indexed.gif")),
             Processes.Argument
               (Files.Join (Fixture_Directory, "generated/imagemagick-animation.gif")),
             Processes.Argument
               (Files.Join (Fixture_Directory, "generated/imagemagick-interlaced.gif"))]),
         "independent fixture metadata check");
      Independent_Frames : constant String := Capture
        (FFprobe,
         Processes.Arguments
           ([Processes.Argument ("-v"), Processes.Argument ("error"),
             Processes.Argument ("-select_streams"), Processes.Argument ("v:0"),
             Processes.Argument ("-count_frames"), Processes.Argument ("-show_entries"),
             Processes.Argument ("stream=nb_read_frames"), Processes.Argument ("-of"),
             Processes.Argument ("default=noprint_wrappers=1"),
             Processes.Argument
               (Files.Join (Fixture_Directory, "generated/imagemagick-animation.gif"))]),
         "independent animation frame check");
   begin
      Require
        (Independent_Metadata =
           "GIF 25x24 1|GIF 24x24 1|GIF 5x3 1|"
           & "GIF 3x1 3|GIF 3x1 3|GIF 3x1 3|GIF 9x9 1|",
         "independent fixture metadata changed");
      Require
        (Project_Tools.Text.Line_Value
           (Independent_Frames, "nb_read_frames", "=") = "3",
         "independent animation frame count changed");
   end;

   Ada.Text_IO.Put_Line
     (Capture (Identify, Processes.Arguments ([Processes.Argument ("-version")]),
               "ImageMagick version"));
   Ada.Text_IO.Put_Line
     (Capture (FFmpeg, Processes.Arguments ([Processes.Argument ("-version")]),
               "FFmpeg version"));
   Project_Tools.Test_Fixtures.Cleanup (Scratch);
   Ada.Text_IO.Put_Line ("Ada external-oracle checks passed");
exception
   when others =>
      Project_Tools.Test_Fixtures.Cleanup (Scratch);
      raise;
end Giflib_External_Checks;
