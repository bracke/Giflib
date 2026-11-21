with Giflib.Quantization.Palette_Building.Fixed_Strategy;
with Giflib.Quantization.Palette_Building.Generated_Strategy;

package body Giflib.Quantization.Palette_Building is
   function Build
     (Context : in out Workspace;
      Source : Images.Image_View;
      Indexed_Pixels : in out Streams.Byte_Array;
      Options : Quantize_Options;
      Constraints : Limits.Limit_Set;
      Work : in out Internal.Work_Budgets.Meter;
      Prepared : out Prepared_Palette) return Results.Result
   is
   begin
      if Options.Palette.Strategy = Use_Fixed_Palette then
         return Fixed_Strategy.Build (Source, Options, Work, Prepared);
      end if;
      return Generated_Strategy.Build
        (Context, Source, Indexed_Pixels, Options, Constraints, Work, Prepared);
   end Build;
end Giflib.Quantization.Palette_Building;
