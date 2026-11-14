separate (Giflib.Testing.Test_Quantization)
procedure Handles_Alpha_Fixed_Palettes_And_Dither
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   RGBA : aliased constant Giflib.Streams.Byte_Array := [255, 0, 0, 0, 0, 255, 0, 255];
   RGBA_View : constant Giflib.Images.Image_View :=
     (Format => Giflib.RGBA_32, Width => 2, Height => 1, Stride => 8,
      Accessible_Bytes => 8, Data => RGBA'Access);
   Gradient : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 16 * 3 => 0];
   Gradient_View : constant Giflib.Images.Image_View :=
     (Data => Gradient'Access,
      Format => Giflib.RGB_24, Width => 16, Height => 1, Stride => 48,
      Accessible_Bytes => 48);
   Indexed : Giflib.Streams.Byte_Array (1 .. 2);
   Dithered, Repeated : Giflib.Streams.Byte_Array (1 .. 16);
   Quantized, Repeated_Result : Giflib.Quantization.Quantization_Result;
   Options : Giflib.Quantization.Quantize_Options := Giflib.Quantization.Default_Options;
   Outcome : Giflib.Results.Result;
begin
   Options.Palette :=
     (Strategy => Giflib.Quantization.Use_Fixed_Palette,
      Fixed_Palette =>
        (Length => 3,
         Colors =>
           [0 => (255, 0, 0),
            1 => (0, 255, 0),
            2 => (0, 0, 0),
            others => <>]),
      Fixed_Transparent_Index => 2);
   Outcome := Giflib.Quantization.Quantize
     (RGBA_View, Indexed, Quantized, Options);
   Assert (Giflib.Results.Succeeded (Outcome)
           and then Quantized.Transparency.Present
           and then Quantized.Transparency.Index = 2
           and then Indexed = [2, 1],
           "alpha threshold or fixed transparent palette mapping failed");
   Options.Transparency := (Enabled => False);
   Outcome := Giflib.Quantization.Quantize
     (RGBA_View, Indexed, Quantized, Options);
   Assert
     (Giflib.Results.Succeeded (Outcome)
      and then not Quantized.Transparency.Present
      and then Indexed = [0, 1],
      "disabled transparency policy retained an alpha threshold or index");

   for I in 0 .. 15 loop
      Gradient (I * 3 + 1) := Giflib.Byte (I * 17);
      Gradient (I * 3 + 2) := Giflib.Byte (I * 17);
      Gradient (I * 3 + 3) := Giflib.Byte (I * 17);
   end loop;
   Options := Giflib.Quantization.Default_Options;
   Options.Palette.Maximum_Colors := 2;
   Options.Dither := Giflib.Quantization.Floyd_Steinberg;
   Outcome := Giflib.Quantization.Quantize
     (Gradient_View, Dithered, Quantized, Options);
   Assert (Giflib.Results.Succeeded (Outcome), "Floyd-Steinberg quantization failed");
   Outcome := Giflib.Quantization.Quantize
     (Gradient_View, Repeated, Repeated_Result, Options);
   Assert (Giflib.Results.Succeeded (Outcome)
           and then Dithered = Repeated
           and then Quantized.Palette = Repeated_Result.Palette,
           "Floyd-Steinberg output was not deterministic");
end Handles_Alpha_Fixed_Palettes_And_Dither;

