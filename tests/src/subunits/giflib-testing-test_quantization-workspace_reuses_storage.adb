separate (Giflib.Testing.Test_Quantization)
procedure Workspace_Reuses_Storage
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Data : aliased constant Giflib.Streams.Byte_Array :=
     [0, 0, 0, 255, 255, 255];
   View : constant Giflib.Images.Image_View :=
     (Format => Giflib.RGB_24, Width => 2, Height => 1, Stride => 6,
      Accessible_Bytes => 6, Data => Data'Access);
   Context : Giflib.Quantization.Workspace;
   Indexed : Giflib.Streams.Byte_Array (1 .. 2);
   Quantized : Giflib.Quantization.Quantization_Result;
   Options : Giflib.Quantization.Quantize_Options :=
     Giflib.Quantization.Default_Options;
   Outcome : Giflib.Results.Result;
begin
   Options.Palette :=
     (Strategy => Giflib.Quantization.Use_Fixed_Palette,
      Fixed_Palette =>
        (Length => 2,
         Colors => [0 => (0, 0, 0), 1 => (255, 255, 255), others => <>]),
      Fixed_Transparent_Index => 0);
   Giflib.Quantization.Testing.Disable_Failure_Injection (Context);
   Outcome := Giflib.Quantization.Quantize
     (Context, View, Indexed, Quantized, Options);
   Assert (Giflib.Results.Succeeded (Outcome)
           and then Giflib.Quantization.Allocated_Bytes (Context) > 0,
           "quantization workspace was not populated");
   Giflib.Quantization.Testing.Inject_Storage_Error_After (Context);
   Outcome := Giflib.Quantization.Quantize
     (Context, View, Indexed, Quantized, Options);
   Assert (Giflib.Results.Succeeded (Outcome),
           "reused quantization workspace allocated again");
   Giflib.Quantization.Testing.Disable_Failure_Injection (Context);
   Giflib.Quantization.Finalize (Context);
   Assert (Giflib.Quantization.Allocated_Bytes (Context) = 0,
           "quantization workspace finalization retained storage");
exception
   when others =>
      Giflib.Quantization.Testing.Disable_Failure_Injection (Context);
      Giflib.Quantization.Finalize (Context);
      raise;
end Workspace_Reuses_Storage;

