separate (Giflib.Testing.Test_Quantizer_Allocation)
procedure Quantizer_Cleanup_Outcomes_Are_Preserved
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
   Context : Giflib.Quantization.Workspace;
   Options : Giflib.Quantization.Quantize_Options :=
     Giflib.Quantization.Default_Options;
   Outcome : Giflib.Results.Result;
   Status : Giflib.Quantization.Cleanup_Status;
begin
   Options.Palette :=
     (Strategy => Giflib.Quantization.Use_Fixed_Palette,
      Fixed_Palette =>
        (Length => 2,
         Colors => [0 => (0, 0, 0), 1 => (255, 255, 255), others => <>]),
      Fixed_Transparent_Index => 0);
   Outcome := Giflib.Quantization.Quantize
     (Context, View, Indexed, Quantized, Options);
   Assert
     (Giflib.Results.Succeeded (Outcome),
      "quantizer cleanup-outcome setup failed");
   Giflib.Quantization.Testing.Corrupt_Allocation_Budget (Context);
   Status := Giflib.Quantization.Release (Context);
   Assert
     (Status = Giflib.Quantization.Cleanup_Accounting_Failed
      and then Giflib.Quantization.Allocated_Bytes (Context) = 0
      and then not Giflib.Quantization.Cleanup_Succeeded (Context)
      and then Giflib.Quantization.First_Cleanup_Status (Context) =
        Giflib.Quantization.Cleanup_Accounting_Failed,
      "quantizer cleanup outcome was collapsed or storage was retained");
   Giflib.Quantization.Testing.Repair_Allocation_Budget (Context);
   Status := Giflib.Quantization.Release (Context);
   Assert
     (Status = Giflib.Quantization.Cleanup_Complete
      and then not Giflib.Quantization.Cleanup_Succeeded (Context)
      and then Giflib.Quantization.First_Cleanup_Status (Context) =
        Giflib.Quantization.Cleanup_Accounting_Failed,
      "quantizer release did not separate current and sticky outcomes");
end Quantizer_Cleanup_Outcomes_Are_Preserved;
