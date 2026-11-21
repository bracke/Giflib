private package Giflib.Optimization.Analysis
  with Preelaborate
is
   function Analyze_Indexed
     (Previous : Streams.Byte_Array;
      Current : Streams.Byte_Array;
      Width : Image_Width;
      Height : Image_Height;
      Previous_Control : Frames.Graphic_Control;
      Current_Control : Frames.Graphic_Control;
      Palettes_Are_Equivalent : Boolean;
      Item : out Frame_Analysis;
      Options : Optimization_Options;
      Constraints : Limits.Limit_Set) return Results.Result;
end Giflib.Optimization.Analysis;
