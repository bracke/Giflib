with Giflib.Palettes;
with Giflib.Results;
with Giflib.Internal.Quantization_Histograms;
with Giflib.Internal.Work_Budgets;

package Giflib.Internal.Quantization_Palette is
   pragma Preelaborate;

   function Build_Median_Cut
     (Histogram       : in out Quantization_Histograms.Histogram_State;
      Generated_Start : Natural;
      Opaque_Capacity : Natural;
      Work            : in out Work_Budgets.Meter;
      Output_Palette  : in out Palettes.Palette) return Results.Result;
end Giflib.Internal.Quantization_Palette;
