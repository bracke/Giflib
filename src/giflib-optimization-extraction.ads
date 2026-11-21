private package Giflib.Optimization.Extraction
  with Preelaborate
is
   function Extract_Indexed_Rectangle
     (Previous : Streams.Byte_Array;
      Current : Streams.Byte_Array;
      Canvas_Width : Image_Width;
      Canvas_Height : Image_Height;
      Item : Frame_Analysis;
      Output : out Streams.Byte_Array;
      Options : Optimization_Options;
      Constraints : Limits.Limit_Set) return Results.Result;
end Giflib.Optimization.Extraction;
