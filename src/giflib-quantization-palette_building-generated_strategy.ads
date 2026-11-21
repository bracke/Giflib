private package Giflib.Quantization.Palette_Building.Generated_Strategy
  with Preelaborate
is
   function Build
     (Context : in out Workspace;
      Source : Images.Image_View;
      Indexed_Pixels : in out Streams.Byte_Array;
      Options : Quantize_Options;
      Constraints : Limits.Limit_Set;
      Work : in out Internal.Work_Budgets.Meter;
      Prepared : out Prepared_Palette) return Results.Result;
end Giflib.Quantization.Palette_Building.Generated_Strategy;
