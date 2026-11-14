separate (Giflib.Testing.Test_Quantization)
procedure Workspace_Respects_Dither_Mode
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Narrow_Data : aliased constant Giflib.Streams.Byte_Array :=
     [0, 0, 0, 255, 255, 255];
   Wide_Data : aliased constant Giflib.Streams.Byte_Array :=
     [0, 0, 0, 85, 85, 85, 170, 170, 170, 255, 255, 255];
   Narrow_View : constant Giflib.Images.Image_View :=
     (Format => Giflib.RGB_24, Width => 2, Height => 1, Stride => 6,
      Accessible_Bytes => 6, Data => Narrow_Data'Access);
   Wide_View : constant Giflib.Images.Image_View :=
     (Format => Giflib.RGB_24, Width => 4, Height => 1, Stride => 12,
      Accessible_Bytes => 12, Data => Wide_Data'Access);
   Context : Giflib.Quantization.Workspace;
   Narrow : Giflib.Streams.Byte_Array (1 .. 2);
   Reused, Fresh : Giflib.Streams.Byte_Array (1 .. 4);
   Quantized, Fresh_Quantized : Giflib.Quantization.Quantization_Result;
   Dither_Options : Giflib.Quantization.Quantize_Options :=
     Giflib.Quantization.Default_Options;
   Outcome : Giflib.Results.Result;
begin
   Dither_Options.Palette.Maximum_Colors := 2;
   Dither_Options.Dither := Giflib.Quantization.Floyd_Steinberg;
   Outcome := Giflib.Quantization.Quantize
     (Context, Narrow_View, Narrow, Quantized, Dither_Options);
   Assert (Giflib.Results.Succeeded (Outcome),
           "initial dithered workspace quantization failed");

   Outcome := Giflib.Quantization.Quantize
     (Context, Wide_View, Reused, Quantized);
   Assert (Giflib.Results.Succeeded (Outcome),
           "retained dither storage affected a no-dither call");
   Outcome := Giflib.Quantization.Quantize
     (Wide_View, Fresh, Fresh_Quantized);
   Assert
     (Giflib.Results.Succeeded (Outcome)
      and then Reused = Fresh
      and then Quantized.Palette = Fresh_Quantized.Palette
      and then Quantized.Transparency.Present =
        Fresh_Quantized.Transparency.Present,
      "workspace reuse changed no-dither output");
   Giflib.Quantization.Finalize (Context);
exception
   when others =>
      Giflib.Quantization.Finalize (Context);
      raise;
end Workspace_Respects_Dither_Mode;

