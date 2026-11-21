private package Giflib.Quantization.Palette_Building.Fixed_Strategy
  with Preelaborate
is
   function Build
     (Source : Images.Image_View;
      Options : Quantize_Options;
      Work : in out Internal.Work_Budgets.Meter;
      Prepared : out Prepared_Palette) return Results.Result;
end Giflib.Quantization.Palette_Building.Fixed_Strategy;
