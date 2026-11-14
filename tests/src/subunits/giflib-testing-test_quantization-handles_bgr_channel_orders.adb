separate (Giflib.Testing.Test_Quantization)
procedure Handles_BGR_Channel_Orders
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   BGR : aliased constant Giflib.Streams.Byte_Array :=
     [0, 0, 255, 0, 255, 0];
   BGRA : aliased constant Giflib.Streams.Byte_Array :=
     [0, 0, 255, 0, 0, 255, 0, 255];
   BGR_View : constant Giflib.Images.Image_View :=
     (Format => Giflib.BGR_24, Width => 2, Height => 1, Stride => 6,
      Accessible_Bytes => 6, Data => BGR'Access);
   BGRA_View : constant Giflib.Images.Image_View :=
     (Format => Giflib.BGRA_32, Width => 2, Height => 1, Stride => 8,
      Accessible_Bytes => 8, Data => BGRA'Access);
   Indexed : Giflib.Streams.Byte_Array (1 .. 2);
   Quantized : Giflib.Quantization.Quantization_Result;
   Outcome : Giflib.Results.Result;
begin
   Outcome := Giflib.Quantization.Quantize
     (BGR_View, Indexed, Quantized);
   Assert (Giflib.Results.Succeeded (Outcome)
           and then not Quantized.Transparency.Present
           and then Indexed = [0, 1]
           and then Quantized.Palette.Colors (0) = (255, 0, 0)
           and then Quantized.Palette.Colors (1) = (0, 255, 0),
           "BGR channel order changed during quantization");

   Outcome := Giflib.Quantization.Quantize
     (BGRA_View, Indexed, Quantized);
   Assert (Giflib.Results.Succeeded (Outcome)
           and then Quantized.Transparency.Present
           and then Quantized.Transparency.Index = 0
           and then Indexed = [0, 1]
           and then Quantized.Palette.Colors (1) = (0, 255, 0),
           "BGRA channel order or alpha handling changed");
end Handles_BGR_Channel_Orders;

