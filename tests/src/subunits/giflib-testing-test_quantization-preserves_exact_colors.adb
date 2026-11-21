separate (Giflib.Testing.Test_Quantization)
procedure Preserves_Exact_Colors (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Data : aliased constant Giflib.Streams.Byte_Array :=
     [255, 0, 0, 0, 255, 0, 0, 0, 255];
   View : constant Giflib.Images.Image_View :=
     (Format => Giflib.RGB_24, Width => 3, Height => 1, Stride => 9,
      Accessible_Bytes => 9, Data => Data'Access);
   Indexed : Giflib.Streams.Byte_Array (1 .. 3);
   Quantized : Giflib.Quantization.Quantization_Result;
   Outcome : Giflib.Results.Result;
begin
   Outcome := Giflib.Quantization.Quantize
     (View, Indexed, Quantized);
   Assert (Giflib.Results.Succeeded (Outcome), "exact quantization failed");
   Assert (not Quantized.Transparency.Present and then Indexed = [0, 1, 2],
           "exact quantization changed color indices");
   Assert
     (Quantized.Palette.Length = 3
      and then Quantized.Palette.Colors (0) = (255, 0, 0)
      and then Quantized.Palette.Colors (1) = (0, 255, 0)
      and then Quantized.Palette.Colors (2) = (0, 0, 255),
      "exact palette did not preserve first-seen colors");

   declare
      One_Pixel : aliased constant Giflib.Streams.Byte_Array := [0, 0, 0];
      One_Pixel_View : constant Giflib.Images.Image_View :=
        (Format => Giflib.RGB_24,
         Width => 1,
         Height => 1,
         Stride => 3,
         Accessible_Bytes => 3,
         Data => One_Pixel'Access);
      Maximum_Bound_Output : Giflib.Streams.Byte_Array
        (Positive'Last .. Positive'Last);
   begin
      Outcome := Giflib.Quantization.Quantize
        (One_Pixel_View,
         Maximum_Bound_Output,
         Quantized);
      Assert
        (Giflib.Results.Succeeded (Outcome)
         and then Maximum_Bound_Output (Positive'Last) = 0,
         "quantization rejected a valid maximum-bound output array");
   end;

   declare
      Transparent : aliased constant Giflib.Streams.Byte_Array :=
        [12, 34, 56, 0, 78, 90, 123, 0];
      Transparent_View : constant Giflib.Images.Image_View :=
        (Format => Giflib.RGBA_32,
         Width => 2,
         Height => 1,
         Stride => 8,
         Accessible_Bytes => 8,
         Data => Transparent'Access);
      Transparent_Indexed : Giflib.Streams.Byte_Array (1 .. 2);
   begin
      Outcome := Giflib.Quantization.Quantize
        (Transparent_View, Transparent_Indexed, Quantized);
      Assert
        (Giflib.Results.Succeeded (Outcome)
         and then Quantized.Transparency.Present
         and then Quantized.Transparency.Index = 0
         and then Transparent_Indexed = [0, 0],
         "all-transparent exact quantization failed");
   end;
end Preserves_Exact_Colors;

