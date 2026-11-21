with Giflib.Optimization.Analysis;
with Giflib.Optimization.Extraction;

package body Giflib.Optimization is
   function Analyze_Indexed
     (Previous : Streams.Byte_Array;
      Current : Streams.Byte_Array;
      Width : Image_Width;
      Height : Image_Height;
      Previous_Control : Frames.Graphic_Control;
      Current_Control : Frames.Graphic_Control;
      Palettes_Are_Equivalent : Boolean;
      Item : out Frame_Analysis;
      Options : Optimization_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits)
      return Results.Result is
     (Analysis.Analyze_Indexed
        (Previous, Current, Width, Height, Previous_Control, Current_Control,
         Palettes_Are_Equivalent, Item, Options, Constraints));

   function Extract_Indexed_Rectangle
     (Previous : Streams.Byte_Array;
      Current : Streams.Byte_Array;
      Canvas_Width : Image_Width;
      Canvas_Height : Image_Height;
      Item : Frame_Analysis;
      Output : out Streams.Byte_Array;
      Options : Optimization_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits)
      return Results.Result is
     (Extraction.Extract_Indexed_Rectangle
        (Previous, Current, Canvas_Width, Canvas_Height, Item, Output,
         Options, Constraints));
end Giflib.Optimization;
