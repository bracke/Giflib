with Giflib.Images;
with Giflib.Limits;
with Giflib.Palettes;
with Giflib.Results;
with Giflib.Streams;

package Giflib.Quantization is
   pragma Preelaborate;

   type Dither_Mode is (No_Dither, Floyd_Steinberg);
   type Palette_Strategy is (Generate_Palette, Use_Fixed_Palette);

   type Quantize_Options is record
      Maximum_Colors : Natural range 2 .. 256 := 256;
      Dither : Dither_Mode := No_Dither;
      Strategy : Palette_Strategy := Generate_Palette;
      Fixed_Palette : Palettes.Palette := (others => <>);
      Use_Transparency : Boolean := True;
      Alpha_Threshold : Byte := 127;
      Fixed_Transparent_Index : Palette_Index := 0;
   end record;

   Default_Options : constant Quantize_Options := (others => <>);

   --  Source and Indexed_Pixels remain caller-owned. Indexed_Pixels must contain
   --  exactly Width * Height bytes. Alpha <= Alpha_Threshold becomes transparent
   --  when transparency is enabled; generated palettes reserve index zero.
   function Quantize
     (Source : Images.Image_View;
      Indexed_Pixels : out Streams.Byte_Array;
      Output_Palette : out Palettes.Palette;
      Has_Transparency : out Boolean;
      Transparent_Index : out Palette_Index;
      Options : Quantize_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits) return Results.Result;
end Giflib.Quantization;
