with Giflib_Oracle_Process;

package Giflib_ImageMagick_Oracle is
   procedure Decode
     (Object : Giflib_Oracle_Process.Runner;
      GIF, Raw, Operation : String);
   function Generated_Metadata
     (Object : Giflib_Oracle_Process.Runner;
      Still, Animation, Truecolor : String) return String;
   function Animation_Details
     (Object : Giflib_Oracle_Process.Runner;
      Animation : String) return String;
   function Independent_Metadata
     (Object : Giflib_Oracle_Process.Runner;
      Fixture_Directory : String) return String;
   function Version (Object : Giflib_Oracle_Process.Runner) return String;
end Giflib_ImageMagick_Oracle;
