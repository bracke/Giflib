separate (Giflib.Testing.Test_Allocation_Failures)
procedure Encoder_Allocation_Failures
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Data : aliased constant Giflib.Streams.Byte_Array :=
     [0, 0, 0, 255, 255, 255];
   View : constant Giflib.Images.Image_View :=
     (Format => Giflib.RGB_24, Width => 2, Height => 1, Stride => 6,
      Accessible_Bytes => 6, Data => Data'Access);
   Storage : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 512 => 0];
   Destination : aliased Giflib.Streams.Fixed_Buffer_Destination (Storage'Access);
   Encoder : Giflib.Encoding.Encoder (Destination'Access);
   Cleanup_Storage : aliased Giflib.Streams.Byte_Array :=
     [for I in 1 .. 512 => 0];
   Cleanup_Destination : aliased Giflib.Streams.Fixed_Buffer_Destination
     (Cleanup_Storage'Access);
   Cleanup_Encoder : Giflib.Encoding.Encoder (Cleanup_Destination'Access);
   Palette : Giflib.Palettes.Palette;
   Indexed : constant Giflib.Streams.Byte_Array := [0, 1];
   Outcome : Giflib.Results.Result;
   Quantize_Options : Giflib.Quantization.Quantize_Options :=
     Giflib.Quantization.Default_Options;

   procedure Start is
   begin
      Giflib.Streams.Open (Destination);
      Outcome := Giflib.Encoding.Initialize
        (Encoder);
      Assert (Giflib.Results.Succeeded (Outcome),
              "allocation encoder initialization failed");
      Outcome := Giflib.Encoding.Define_Screen
        (Encoder, (Width => 2, Height => 1, others => <>));
      Assert (Giflib.Results.Succeeded (Outcome),
              "allocation encoder setup failed");
   end Start;
begin
   Giflib.Encoding.Testing.Disable_Failure_Injection (Encoder);
   Palette.Length := 2;
   Palette.Colors (0) := (0, 0, 0);
   Palette.Colors (1) := (255, 255, 255);

   Start;
   Giflib.Encoding.Testing.Inject_Storage_Error_After (Encoder);
   Outcome := Giflib.Encoding.Add_Indexed_Frame
     (Encoder,
      (Width => 2, Height => 1, others => <>),
      Giflib.Encoding.Use_Local_Palette,
      Palette,
      Indexed);
   Require_Allocation_Failure
     (Outcome, "encoder LZW-workspace Storage_Error escaped");
   Assert (Destination.Offset = 0,
           "encoder wrote output before reserving its LZW workspace");
   Assert (Giflib.Encoding.Testing.Allocated_Bytes (Encoder) = 0,
           "failed encoder LZW allocation retained its budget charge");
   Giflib.Encoding.Finalize (Encoder);

   Giflib.Streams.Open (Cleanup_Destination);
   Outcome := Giflib.Encoding.Initialize (Cleanup_Encoder);
   Assert (Giflib.Results.Succeeded (Outcome),
           "cleanup encoder initialization failed");
   Outcome := Giflib.Encoding.Define_Screen
     (Cleanup_Encoder, (Width => 2, Height => 1, others => <>));
   Assert (Giflib.Results.Succeeded (Outcome),
           "cleanup encoder setup failed");
   Quantize_Options.Dither := Giflib.Quantization.Floyd_Steinberg;
   Outcome := Giflib.Encoding.Add_Truecolor_Frame
     (Cleanup_Encoder, (Width => 2, Height => 1, others => <>), View,
      Quantize_Options);
   Assert (Giflib.Results.Succeeded (Outcome),
           "quantizer cleanup fixture did not allocate its workspace");
   Giflib.Encoding.Testing.Corrupt_Quantizer_Allocation_Budget
     (Cleanup_Encoder);
   Outcome := Giflib.Encoding.Cancel (Cleanup_Encoder);
   Assert
     (Outcome.First_Error.Code = Giflib.Errors.Internal_Invariant_Failed
      and then not Giflib.Encoding.Testing.Quantizer_Cleanup_Succeeded
        (Cleanup_Encoder),
      "quantizer cleanup failure was not propagated to the encoder");
   Giflib.Encoding.Finalize (Cleanup_Encoder);

   Start;
   Giflib.Encoding.Testing.Inject_Storage_Error_After (Encoder);
   Outcome := Giflib.Encoding.Add_Truecolor_Frame
     (Encoder, (Width => 2, Height => 1, others => <>), View);
   Require_Allocation_Failure (Outcome, "truecolor-pixel Storage_Error escaped");
   Assert (Giflib.Encoding.State (Encoder) = Giflib.Encoding.Failed,
           "pixel allocation failure did not fail the encoder");
   Giflib.Encoding.Finalize (Encoder);

   Start;
   Giflib.Encoding.Testing.Inject_Quantizer_Storage_Error_After (Encoder);
   Outcome := Giflib.Encoding.Add_Truecolor_Frame
     (Encoder, (Width => 2, Height => 1, others => <>), View);
   Require_Allocation_Failure
     (Outcome, "nested quantizer Storage_Error escaped truecolor encoding");
   Giflib.Encoding.Finalize (Encoder);

   Start;
   Outcome := Giflib.Encoding.Add_Truecolor_Frame
     (Encoder, (Width => 2, Height => 1, others => <>), View);
   Assert (Giflib.Results.Succeeded (Outcome),
           "encoder did not recover after injected allocation failures");
   Giflib.Encoding.Testing.Inject_Storage_Error_After (Encoder);
   Outcome := Giflib.Encoding.Add_Truecolor_Frame
     (Encoder, (Width => 2, Height => 1, others => <>), View);
   Assert (Giflib.Results.Succeeded (Outcome),
           "same-sized truecolor frame allocated a new workspace");
   Giflib.Encoding.Finalize (Encoder);
   Giflib.Encoding.Testing.Disable_Failure_Injection (Encoder);
exception
   when others =>
      Giflib.Encoding.Testing.Disable_Failure_Injection (Encoder);
      raise;
end Encoder_Allocation_Failures;

