with Giflib.Internal.Quantization_Storage;
with Giflib.Internal.Work_Budgets;
with Giflib.Palettes;
with Giflib.Results;

package Giflib.Internal.Quantization_Mapping is
   pragma Preelaborate;

   function Find
     (Object : in out Quantization_Storage.Resources;
      Color : Palettes.RGB_Color;
      Output_Palette : Palettes.Palette;
      First : Natural;
      Exclude_Index : Boolean;
      Excluded_Index : Palette_Index;
      Work : in out Work_Budgets.Meter;
      Chosen : out Palette_Index) return Results.Result;
end Giflib.Internal.Quantization_Mapping;
