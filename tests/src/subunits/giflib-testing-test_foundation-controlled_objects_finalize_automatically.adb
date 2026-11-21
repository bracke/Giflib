separate (Giflib.Testing.Test_Foundation)
procedure Controlled_Objects_Finalize_Automatically
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   GIF_Data : aliased constant Giflib.Streams.Byte_Array :=
     [16#47#, 16#49#, 16#46#, 16#38#, 16#39#, 16#61#,
      1, 0, 1, 0, 16#80#, 0, 0,
      0, 0, 0, 255, 255, 255, 16#3B#];
   Source : aliased Giflib.Streams.Memory_Source (GIF_Data'Access);
   Destination_Data : aliased Giflib.Streams.Byte_Array :=
     [for I in 1 .. 1_024 => 0];
   Destination : aliased Giflib.Streams.Fixed_Buffer_Destination (Destination_Data'Access);
   RGB : aliased constant Giflib.Streams.Byte_Array := [0, 0, 0];
   View : constant Giflib.Images.Image_View :=
     (Format => Giflib.RGB_24,
      Width => 1,
      Height => 1,
      Stride => 3,
      Accessible_Bytes => 3,
      Data => RGB'Access);
   Indexed : Giflib.Streams.Byte_Array (1 .. 1);
   Quantized : Giflib.Quantization.Quantization_Result;
   Outcome : Giflib.Results.Result;
begin
   Giflib.Streams.Open (Source);
   declare
      Object : Giflib.Decoding.Decoder (Source'Access);
      Header : Giflib.Decoding.Header_Info;
      Options : Giflib.Decoding.Decode_Options :=
        Giflib.Decoding.Default_Options;
   begin
      Options.Mode := Giflib.Decoding.Composited_RGBA;
      Outcome := Giflib.Decoding.Initialize
        (Object, Options);
      Assert (Giflib.Results.Succeeded (Outcome),
              "automatic-finalization decoder initialization failed");
      Outcome := Giflib.Decoding.Read_Header (Object, Header);
      Assert
        (Giflib.Results.Succeeded (Outcome)
         and then Giflib.Decoding.Testing.Allocated_Bytes (Object) > 0,
         "automatic-finalization decoder did not own a canvas");
   end;

   Giflib.Streams.Open
     (Destination);
   declare
      Object : Giflib.Encoding.Encoder (Destination'Access);
   begin
      Outcome := Giflib.Encoding.Initialize
        (Object);
      Assert (Giflib.Results.Succeeded (Outcome),
              "automatic-finalization encoder initialization failed");
      Outcome := Giflib.Encoding.Define_Screen (Object, (others => <>));
      Assert (Giflib.Results.Succeeded (Outcome),
              "automatic-finalization encoder setup failed");
      Outcome := Giflib.Encoding.Add_Truecolor_Frame
        (Object, (others => <>), View);
      Assert
        (Giflib.Results.Succeeded (Outcome)
         and then Giflib.Encoding.Testing.Allocated_Bytes (Object) > 0,
         "automatic-finalization encoder did not own a workspace");
   end;

   declare
      Object : Giflib.Quantization.Workspace;
      Options : Giflib.Quantization.Quantize_Options :=
        Giflib.Quantization.Default_Options;
   begin
      Options.Palette :=
        (Strategy => Giflib.Quantization.Use_Fixed_Palette,
         Fixed_Palette => (Length => 2, others => <>),
         Fixed_Transparent_Index => 0);
      Outcome := Giflib.Quantization.Quantize
        (Object, View, Indexed, Quantized, Options);
      Assert
        (Giflib.Results.Succeeded (Outcome)
         and then Giflib.Quantization.Allocated_Bytes (Object) > 0,
         "automatic-finalization quantizer did not retain storage");
   end;
   --  Reaching this point verifies that all three controlled finalizers ran
   --  during scope exit without propagating an exception.
end Controlled_Objects_Finalize_Automatically;

