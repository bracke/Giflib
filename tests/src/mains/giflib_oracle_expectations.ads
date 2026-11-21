package Giflib_Oracle_Expectations is
   procedure Truecolor_Quality (Path, Description : String);
   procedure Generated_Metadata
     (ImageMagick_Metadata, Animation_Details, FFprobe_Metadata : String);
   procedure Independent_Metadata
     (ImageMagick_Metadata, FFprobe_Frames,
      Large_Animation_Metadata : String);
end Giflib_Oracle_Expectations;
