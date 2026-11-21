with Project_Tools.Files;
with Project_Tools.Processes;

package body Giflib_FFmpeg_Oracle is
   package Files renames Project_Tools.Files;
   package Processes renames Project_Tools.Processes;

   procedure Decode
     (Object : Giflib_Oracle_Process.Runner;
      GIF, Raw, Operation : String) is
   begin
      Giflib_Oracle_Process.Run
        (Object, "FFmpeg " & Operation,
         Processes.Arguments
           ([Processes.Argument ("-y"), Processes.Argument ("-v"),
             Processes.Argument ("error"), Processes.Argument ("-i"),
             Processes.Argument (GIF), Processes.Argument ("-vsync"),
             Processes.Argument ("0"), Processes.Argument ("-f"),
             Processes.Argument ("rawvideo"), Processes.Argument ("-pix_fmt"),
             Processes.Argument ("rgba"), Processes.Argument (Raw)]));
   end Decode;

   function Probe
     (Object : Giflib_Oracle_Process.Runner;
      GIF, Entries, Operation : String) return String is
     (Giflib_Oracle_Process.Capture
        (Object, Operation,
         Processes.Arguments
           ([Processes.Argument ("-v"), Processes.Argument ("error"),
             Processes.Argument ("-select_streams"), Processes.Argument ("v:0"),
             Processes.Argument ("-count_frames"), Processes.Argument ("-show_entries"),
             Processes.Argument (Entries), Processes.Argument ("-of"),
             Processes.Argument ("default=noprint_wrappers=1"),
             Processes.Argument (GIF)])));

   function Generated_Metadata
     (Object : Giflib_Oracle_Process.Runner;
      Animation : String) return String is
     (Probe (Object, Animation,
             "stream=codec_name,width,height,nb_read_frames",
             "FFprobe metadata check"));

   function Independent_Frames
     (Object : Giflib_Oracle_Process.Runner;
      Fixture_Directory : String) return String is
     (Probe
        (Object,
         Files.Join (Fixture_Directory, "generated/imagemagick-animation.gif"),
         "stream=nb_read_frames", "independent animation frame check"));

   function Large_Animation_Metadata
     (Object : Giflib_Oracle_Process.Runner;
      Fixture_Directory : String) return String is
     (Probe
        (Object,
         Files.Join
           (Fixture_Directory,
            "generated/imagemagick-benchmark-animation-256.gif"),
         "stream=width,height,nb_read_frames",
         "independent large animation metadata check"));

   function Version (Object : Giflib_Oracle_Process.Runner) return String is
     (Giflib_Oracle_Process.Capture
        (Object, "FFmpeg version",
         Processes.Arguments ([Processes.Argument ("-version")])));
end Giflib_FFmpeg_Oracle;
