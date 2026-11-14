separate (Giflib.Testing.Test_Quantization)
procedure Quantizes_Many_Colors_Deterministically (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Data : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 17 * 17 * 3 => 0];
   View : constant Giflib.Images.Image_View :=
     (Data => Data'Access,
      Format => Giflib.RGB_24, Width => 17, Height => 17, Stride => 51,
      Accessible_Bytes => Data'Length);
   First, Second : Giflib.Streams.Byte_Array (1 .. 17 * 17);
   First_Result, Second_Result : Giflib.Quantization.Quantization_Result;
   Options : Giflib.Quantization.Quantize_Options := Giflib.Quantization.Default_Options;
   Outcome : Giflib.Results.Result;
   Position : Natural := Data'First;
   Error_Sum : Long_Long_Integer := 0;
   Chosen : Giflib.Palettes.RGB_Color;
   Pixel : Natural := First'First;
begin
   for Y in 0 .. 16 loop
      for X in 0 .. 16 loop
         Data (Position) := Giflib.Byte (X * 15);
         Data (Position + 1) := Giflib.Byte (Y * 15);
         Data (Position + 2) := Giflib.Byte ((X * 17 + Y) mod 256);
         Position := Position + 3;
      end loop;
   end loop;
   Options.Palette.Maximum_Colors := 16;
   Outcome := Giflib.Quantization.Quantize
     (View, First, First_Result, Options);
   Assert (Giflib.Results.Succeeded (Outcome), "median-cut quantization failed");
   Outcome := Giflib.Quantization.Quantize
     (View, Second, Second_Result, Options);
   Assert (Giflib.Results.Succeeded (Outcome), "repeat median-cut quantization failed");
   Assert (First = Second and then First_Result.Palette = Second_Result.Palette,
           "median-cut output was not deterministic");
   Assert (First_Result.Palette.Length = 16
           and then not First_Result.Transparency.Present,
           "median-cut palette size was wrong");
   Position := Data'First;
   for I in First'Range loop
      Pixel := Natural (First (I));
      Chosen := First_Result.Palette.Colors (Giflib.Palette_Index (Pixel));
      Error_Sum := Error_Sum
        + (Long_Long_Integer (Data (Position)) - Long_Long_Integer (Chosen.Red)) ** 2
        + (Long_Long_Integer (Data (Position + 1)) - Long_Long_Integer (Chosen.Green)) ** 2
        + (Long_Long_Integer (Data (Position + 2)) - Long_Long_Integer (Chosen.Blue)) ** 2;
      Position := Position + 3;
   end loop;
   Assert (Error_Sum / Long_Long_Integer (First'Length * 3) < 4_000,
           "median-cut quality exceeded the RGB mean-square threshold");
end Quantizes_Many_Colors_Deterministically;

