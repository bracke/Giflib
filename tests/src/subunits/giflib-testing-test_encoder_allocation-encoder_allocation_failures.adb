separate (Giflib.Testing.Test_Encoder_Allocation)
procedure Encoder_Allocation_Failures
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Data : aliased constant Giflib.Streams.Byte_Array :=
     [0, 0, 0, 255, 255, 255];
   View : constant Giflib.Images.Image_View :=
     (Format => Giflib.RGB_24, Width => 2, Height => 1, Stride => 6,
      Accessible_Bytes => 6, Data => Data'Access);
   Truecolor_Pixel_Charge : constant Giflib.Byte_Count :=
     Giflib.Byte_Count (View.Width) * Giflib.Byte_Count (View.Height);
   Storage : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 512 => 0];
   Destination : aliased Giflib.Streams.Fixed_Buffer_Destination (Storage'Access);
   Encoder : Giflib.Encoding.Encoder (Destination'Access);
   Cleanup_Storage : aliased Giflib.Streams.Byte_Array :=
     [for I in 1 .. 512 => 0];
   Cleanup_Destination : aliased Giflib.Streams.Fixed_Buffer_Destination
     (Cleanup_Storage'Access);
   Cleanup_Encoder : Giflib.Encoding.Encoder (Cleanup_Destination'Access);
   Outer_Cleanup_Storage : aliased Giflib.Streams.Byte_Array :=
     [for I in 1 .. 512 => 0];
   Outer_Cleanup_Destination : aliased Giflib.Streams.Fixed_Buffer_Destination
     (Outer_Cleanup_Storage'Access);
   Outer_Cleanup_Encoder : Giflib.Encoding.Encoder
     (Outer_Cleanup_Destination'Access);
   Palette : Giflib.Palettes.Palette;
   Indexed : constant Giflib.Streams.Byte_Array := [0, 1];
   Outcome : Giflib.Results.Result;
   Quantize_Options : Giflib.Quantization.Quantize_Options :=
     Giflib.Quantization.Default_Options;
   Quantizer : Giflib.Quantization.Workspace;
   Quantized_Pixels : Giflib.Streams.Byte_Array (1 .. 2);
   Quantized : Giflib.Quantization.Quantization_Result;
   Quantizer_Failure : Giflib.Results.Result;

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
      (Selection => Giflib.Encoding.Use_Local_Palette, Value => Palette),
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
   Quantize_Options.Palette :=
     (Strategy => Giflib.Quantization.Use_Fixed_Palette,
      Fixed_Palette => Palette,
      Fixed_Transparent_Index => 0);
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
        (Cleanup_Encoder)
      and then Giflib.Encoding.Testing.Last_Cleanup (Cleanup_Encoder) =
        Giflib.Quantization.Cleanup_Accounting_Failed
      and then Giflib.Encoding.First_Cleanup_Status (Cleanup_Encoder) =
        Giflib.Cleanup.Cleanup_Accounting_Failed,
      "quantizer cleanup failure was not propagated to the encoder");
   Giflib.Encoding.Testing.Repair_Quantizer_Allocation_Budget
     (Cleanup_Encoder);
   Giflib.Encoding.Finalize (Cleanup_Encoder);
   Outcome := Giflib.Encoding.Initialize (Cleanup_Encoder);
   Assert
     (not Giflib.Results.Succeeded (Outcome)
      and then Giflib.Encoding.State (Cleanup_Encoder) = Giflib.Encoding.Failed
      and then Giflib.Encoding.First_Cleanup_Status (Cleanup_Encoder) =
        Giflib.Cleanup.Cleanup_Accounting_Failed,
      "encoder reused a session with a sticky cleanup failure");
   Giflib.Encoding.Finalize (Cleanup_Encoder);

   Giflib.Streams.Open (Outer_Cleanup_Destination);
   Outcome := Giflib.Encoding.Initialize (Outer_Cleanup_Encoder);
   Assert (Giflib.Results.Succeeded (Outcome),
           "outer cleanup encoder initialization failed");
   Outcome := Giflib.Encoding.Define_Screen
     (Outer_Cleanup_Encoder, (Width => 2, Height => 1, others => <>));
   Assert (Giflib.Results.Succeeded (Outcome),
           "outer cleanup encoder setup failed");
   Outcome := Giflib.Encoding.Add_Truecolor_Frame
     (Outer_Cleanup_Encoder,
      (Width => 2, Height => 1, others => <>),
      View);
   Assert (Giflib.Results.Succeeded (Outcome),
           "outer cleanup fixture did not allocate resources");
   Giflib.Encoding.Testing.Corrupt_Allocation_Budget
     (Outer_Cleanup_Encoder);
   Outcome := Giflib.Encoding.Cancel (Outer_Cleanup_Encoder);
   Assert
     (Outcome.First_Error.Code = Giflib.Errors.Internal_Invariant_Failed
      and then Giflib.Encoding.Testing.Resources_Released
        (Outer_Cleanup_Encoder)
      and then Giflib.Encoding.Testing.Last_Cleanup (Outer_Cleanup_Encoder) =
        Giflib.Quantization.Cleanup_Accounting_Failed
      and then Giflib.Encoding.First_Cleanup_Status
        (Outer_Cleanup_Encoder) = Giflib.Cleanup.Cleanup_Accounting_Failed,
      "outer encoder cleanup failure lost its status or retained owned storage");
   Giflib.Encoding.Finalize (Outer_Cleanup_Encoder);

   Start;
   Giflib.Encoding.Testing.Inject_Storage_Error_After (Encoder);
   Outcome := Giflib.Encoding.Add_Truecolor_Frame
     (Encoder, (Width => 2, Height => 1, others => <>), View);
   Require_Allocation_Failure (Outcome, "truecolor-pixel Storage_Error escaped");
   Assert (Giflib.Encoding.State (Encoder) = Giflib.Encoding.Failed,
           "pixel allocation failure did not fail the encoder");
   Giflib.Encoding.Finalize (Encoder);

   Giflib.Quantization.Testing.Inject_Storage_Error_After (Quantizer);
   Quantizer_Failure := Giflib.Quantization.Quantize
     (Quantizer, View, Quantized_Pixels, Quantized, Quantize_Options);
   Require_Allocation_Failure
     (Quantizer_Failure, "standalone quantizer Storage_Error escaped");
   Giflib.Quantization.Finalize (Quantizer);

   Start;
   Giflib.Encoding.Testing.Inject_Quantizer_Storage_Error_After (Encoder);
   Outcome := Giflib.Encoding.Add_Truecolor_Frame
     (Encoder, (Width => 2, Height => 1, others => <>), View,
      Quantize_Options);
   Require_Allocation_Failure
     (Outcome, "nested quantizer Storage_Error escaped truecolor encoding");
   Assert
     (Outcome.First_Error.Context.Actual =
        Quantizer_Failure.First_Error.Context.Actual + Truecolor_Pixel_Charge,
      "nested host allocation failure did not report the session total");
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
      Giflib.Quantization.Testing.Disable_Failure_Injection (Quantizer);
      raise;
end Encoder_Allocation_Failures;

