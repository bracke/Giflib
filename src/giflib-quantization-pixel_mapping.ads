with Giflib.Internal.Work_Budgets;
with Giflib.Quantization.Palette_Building;

private package Giflib.Quantization.Pixel_Mapping
  with Preelaborate
is
   function Map
     (Context : in out Workspace;
      Source : Images.Image_View;
      Indexed_Pixels : out Streams.Byte_Array;
      Prepared : Palette_Building.Prepared_Palette;
      Options : Quantize_Options;
      Constraints : Limits.Limit_Set;
      Work : in out Internal.Work_Budgets.Meter) return Results.Result;
end Giflib.Quantization.Pixel_Mapping;
