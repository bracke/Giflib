with Project_Tools.Files;
with Project_Tools.Processes;

package body Giflib_ImageMagick_Oracle is
   package Files renames Project_Tools.Files;
   package Processes renames Project_Tools.Processes;

   procedure Decode
     (Object : Giflib_Oracle_Process.Runner;
      GIF, Raw, Operation : String) is
   begin
      Giflib_Oracle_Process.Run
        (Object, "ImageMagick " & Operation,
         Processes.Arguments
           ([Processes.Argument (GIF), Processes.Argument ("-coalesce"),
             Processes.Argument ("-depth"), Processes.Argument ("8"),
             Processes.Argument ("rgba:" & Raw)]));
   end Decode;

   function Generated_Metadata
     (Object : Giflib_Oracle_Process.Runner;
      Still, Animation, Truecolor : String) return String is
     (Giflib_Oracle_Process.Capture
        (Object, "ImageMagick metadata check",
         Processes.Arguments
           ([Processes.Argument ("-format"),
             Processes.Argument ("%m %wx%h %n %T|"),
             Processes.Argument (Still), Processes.Argument (Animation),
             Processes.Argument (Truecolor)])));

   function Animation_Details
     (Object : Giflib_Oracle_Process.Runner;
      Animation : String) return String is
     (Giflib_Oracle_Process.Capture
        (Object, "ImageMagick animation detail check",
         Processes.Arguments
           ([Processes.Argument ("-verbose"), Processes.Argument (Animation)])));

   function Independent_Metadata
     (Object : Giflib_Oracle_Process.Runner;
      Fixture_Directory : String) return String is
     (Giflib_Oracle_Process.Capture
        (Object, "independent fixture metadata check",
         Processes.Arguments
           ([Processes.Argument ("-format"), Processes.Argument ("%m %wx%h %n|"),
             Processes.Argument (Files.Join (Fixture_Directory, "external/docbook-tip.gif")),
             Processes.Argument (Files.Join (Fixture_Directory, "external/docbook-warning.gif")),
             Processes.Argument (Files.Join (Fixture_Directory, "generated/imagemagick-indexed.gif")),
             Processes.Argument (Files.Join (Fixture_Directory, "generated/imagemagick-animation.gif")),
             Processes.Argument (Files.Join (Fixture_Directory, "generated/imagemagick-interlaced.gif"))])));

   function Version (Object : Giflib_Oracle_Process.Runner) return String is
     (Giflib_Oracle_Process.Capture
        (Object, "ImageMagick version",
         Processes.Arguments ([Processes.Argument ("-version")])));
end Giflib_ImageMagick_Oracle;
