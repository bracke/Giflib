separate (Giflib.Testing.Test_Quantizer_Allocation)
procedure Quantizer_Allocation_Failures
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Data : aliased constant Giflib.Streams.Byte_Array :=
     [0, 0, 0, 255, 255, 255];
   View : constant Giflib.Images.Image_View :=
     (Format => Giflib.RGB_24, Width => 2, Height => 1, Stride => 6,
      Accessible_Bytes => 6, Data => Data'Access);
   Indexed : Giflib.Streams.Byte_Array (1 .. 2);
   Quantized : Giflib.Quantization.Quantization_Result;
   Options : Giflib.Quantization.Quantize_Options :=
     Giflib.Quantization.Default_Options;
   Context : Giflib.Quantization.Workspace;
   Outcome : Giflib.Results.Result;
begin
   Giflib.Quantization.Testing.Inject_Storage_Error_After (Context);
   Outcome := Giflib.Quantization.Quantize
     (Context, View, Indexed, Quantized);
   Require_Allocation_Failure (Outcome, "nearest-cache Storage_Error escaped");
   Giflib.Quantization.Finalize (Context);

   Giflib.Quantization.Testing.Inject_Storage_Error_After (Context, 1);
   Outcome := Giflib.Quantization.Quantize
     (Context, View, Indexed, Quantized, Options);
   Require_Allocation_Failure (Outcome, "histogram Storage_Error escaped");
   Giflib.Quantization.Finalize (Context);

   Options.Palette :=
     (Strategy => Giflib.Quantization.Use_Fixed_Palette,
      Fixed_Palette =>
        (Length => 2,
         Colors => [0 => (0, 0, 0), 1 => (255, 255, 255), others => <>]),
      Fixed_Transparent_Index => 0);
   Giflib.Quantization.Testing.Inject_Storage_Error_After (Context, 1);
   Outcome := Giflib.Quantization.Quantize
     (Context, View, Indexed, Quantized, Options);
   Assert (Giflib.Results.Succeeded (Outcome),
           "fixed-palette quantization allocated a histogram");
   Giflib.Quantization.Testing.Disable_Failure_Injection (Context);
   Giflib.Quantization.Finalize (Context);

   Options := Giflib.Quantization.Default_Options;
   Options.Dither := Giflib.Quantization.Floyd_Steinberg;
   Giflib.Quantization.Testing.Inject_Storage_Error_After (Context, 2);
   Outcome := Giflib.Quantization.Quantize
     (Context, View, Indexed, Quantized, Options);
   Require_Allocation_Failure (Outcome, "dither-buffer Storage_Error escaped");

   Outcome := Giflib.Quantization.Quantize
     (Context, View, Indexed, Quantized, Options);
   Assert (Giflib.Results.Succeeded (Outcome),
           "quantizer did not recover after injected allocation failures");
   Giflib.Quantization.Finalize (Context);
exception
   when others =>
      Giflib.Quantization.Testing.Disable_Failure_Injection (Context);
      Giflib.Quantization.Finalize (Context);
      raise;
end Quantizer_Allocation_Failures;

