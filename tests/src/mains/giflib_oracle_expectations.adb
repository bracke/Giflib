with Giflib_Oracle_Assertions;
with Project_Tools.Files;
with Project_Tools.Text;

package body Giflib_Oracle_Expectations is
   procedure Truecolor_Quality (Path, Description : String) is
      Raw : constant String := Project_Tools.Files.Read_Raw_File (Path);
      Error_Sum : Long_Long_Integer := 0;
      Position : Natural := Raw'First;
   begin
      Giflib_Oracle_Assertions.Require
        (Raw'Length = 17 * 17 * 4, Description & " dimensions changed");
      for Y in 0 .. 16 loop
         for X in 0 .. 16 loop
            Error_Sum := Error_Sum
              + (Long_Long_Integer (Character'Pos (Raw (Position)))
                 - Long_Long_Integer (X * 15)) ** 2
              + (Long_Long_Integer (Character'Pos (Raw (Position + 1)))
                 - Long_Long_Integer (Y * 15)) ** 2
              + (Long_Long_Integer (Character'Pos (Raw (Position + 2)))
                 - Long_Long_Integer ((X * 17 + Y) mod 256)) ** 2;
            Giflib_Oracle_Assertions.Require
              (Character'Pos (Raw (Position + 3)) = 255,
               Description & " introduced unexpected transparency");
            Position := Position + 4;
         end loop;
      end loop;
      Giflib_Oracle_Assertions.Require
        (Error_Sum / Long_Long_Integer (17 * 17 * 3) < 5_000,
         Description & " exceeded the RGB mean-square threshold");
   end Truecolor_Quality;

   procedure Generated_Metadata
     (ImageMagick_Metadata, Animation_Details, FFprobe_Metadata : String) is
   begin
      Giflib_Oracle_Assertions.Require
        (ImageMagick_Metadata =
           "GIF 3x2 1 0|GIF 2x1 2 3|GIF 1x1 2 0|GIF 17x17 1 0|",
         "ImageMagick reported incorrect generated metadata");
      Giflib_Oracle_Assertions.Require
        (Project_Tools.Text.Line_Value
           (Animation_Details, "  Iterations", ":") = "0",
         "ImageMagick reported an incorrect animation loop count");
      Giflib_Oracle_Assertions.Require
        (Project_Tools.Text.Line_Value
           (FFprobe_Metadata, "codec_name", "=") = "gif",
         "FFprobe did not select the GIF codec");
      Giflib_Oracle_Assertions.Require
        (Project_Tools.Text.Line_Value (FFprobe_Metadata, "width", "=") = "2"
         and then Project_Tools.Text.Line_Value
           (FFprobe_Metadata, "height", "=") = "1"
         and then Project_Tools.Text.Line_Value
           (FFprobe_Metadata, "nb_read_frames", "=") = "2",
         "FFprobe rejected animation dimensions/frame count");
   end Generated_Metadata;

   procedure Independent_Metadata
     (ImageMagick_Metadata, FFprobe_Frames,
      Large_Animation_Metadata : String) is
   begin
      Giflib_Oracle_Assertions.Require
        (ImageMagick_Metadata =
           "GIF 25x24 1|GIF 24x24 1|GIF 5x3 1|GIF 3x1 3|"
           & "GIF 3x1 3|GIF 3x1 3|GIF 9x9 1|",
         "independent fixture metadata changed");
      Giflib_Oracle_Assertions.Require
        (Project_Tools.Text.Line_Value
           (FFprobe_Frames, "nb_read_frames", "=") = "3",
         "independent animation frame count changed");
      Giflib_Oracle_Assertions.Require
        (Project_Tools.Text.Line_Value
           (Large_Animation_Metadata, "width", "=") = "256"
         and then Project_Tools.Text.Line_Value
           (Large_Animation_Metadata, "height", "=") = "256"
         and then Project_Tools.Text.Line_Value
           (Large_Animation_Metadata, "nb_read_frames", "=") = "8",
         "independent large animation dimensions/frame count changed");
   end Independent_Metadata;
end Giflib_Oracle_Expectations;
