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
   Outcome : Giflib.Results.Result;
   Status : Giflib.Quantization.Cleanup_Status;
begin
   Outcome := Giflib.Quantization.Quantize
     (Context, View, Indexed, Quantized);
   Assert
     (Giflib.Results.Succeeded (Outcome),
      "quantizer cleanup-outcome setup failed");
   Giflib.Quantization.Testing.Corrupt_Allocation_Budget (Context);
   Status := Giflib.Quantization.Release (Context);
   Assert
     (Status = Giflib.Quantization.Cleanup_Accounting_Failed
      and then Giflib.Quantization.Allocated_Bytes (Context) = 0
      and then not Giflib.Quantization.Cleanup_Succeeded (Context),
      "quantizer cleanup outcome was collapsed or storage was retained");
end Quantizer_Cleanup_Outcomes_Are_Preserved;
