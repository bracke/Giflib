separate (Giflib.Testing.Test_Encoding)
procedure Destination_Exceptions_Are_Diagnostics
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Destination : aliased Raising_Destination;
   Delayed : aliased Delayed_Raising_Destination;
   Encoder : Giflib.Encoding.Encoder (Destination'Access);
   Delayed_Encoder : Giflib.Encoding.Encoder (Delayed'Access);
   Frame : constant Giflib.Encoding.Frame_Info :=
     (Left => 0, Top => 0, Width => 1, Height => 1, others => <>);
   RGB : aliased constant Giflib.Streams.Byte_Array := [0, 0, 0];
   View : constant Giflib.Images.Image_View :=
     (Format => Giflib.RGB_24,
      Width => 1,
      Height => 1,
      Stride => 3,
      Accessible_Bytes => 3,
      Data => RGB'Access);
   Outcome : Giflib.Results.Result;
begin
   Outcome := Giflib.Encoding.Initialize
     (Encoder);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Encoding.Define_Screen
     (Encoder, (Width => 1, Height => 1, others => <>));
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Encoding.Set_Global_Palette (Encoder, BW_Palette);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Encoding.Add_Indexed_Frame
     (Encoder,
      Frame,
      Giflib.Encoding.Global_Frame_Palette,
      [1 => 0]);
   Assert
     (Outcome.First_Error.Code = Giflib.Errors.Destination_Write_Failed,
      "indexed destination Storage_Error was misclassified");

   Giflib.Encoding.Finalize (Encoder);
   Outcome := Giflib.Encoding.Initialize
     (Encoder);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Encoding.Define_Screen
     (Encoder, (Width => 1, Height => 1, others => <>));
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Encoding.Add_Truecolor_Frame (Encoder, Frame, View);
   Assert
     (Outcome.First_Error.Code = Giflib.Errors.Destination_Write_Failed,
      "truecolor destination Storage_Error was misclassified");
   Giflib.Encoding.Finalize (Encoder);

   Delayed.Raise_On_Write := 7;
   Outcome := Giflib.Encoding.Initialize
     (Delayed_Encoder);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Encoding.Define_Screen
     (Delayed_Encoder, (Width => 1, Height => 1, others => <>));
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Encoding.Set_Global_Palette (Delayed_Encoder, BW_Palette);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Encoding.Add_Indexed_Frame
     (Delayed_Encoder,
      Frame,
      Giflib.Encoding.Global_Frame_Palette,
      [1 => 0]);
   Assert
     (Outcome.First_Error.Code = Giflib.Errors.Destination_Write_Failed
      and then Giflib.Encoding.State (Delayed_Encoder) = Giflib.Encoding.Failed
      and then Giflib.Encoding.Testing.Bytes_Written (Delayed_Encoder) =
        Giflib.Byte_Count (Delayed.Position)
      and then Giflib.Encoding.Testing.Compressed_Bytes_Written
        (Delayed_Encoder) = 0,
      "LZW destination Storage_Error escaped the encoder");
   Giflib.Encoding.Finalize (Delayed_Encoder);

   Delayed.Position := 0;
   Delayed.Write_Count := 0;
   Delayed.Raise_On_Write := 0;
   Delayed.Raise_On_Flush := True;
   Outcome := Giflib.Encoding.Initialize
     (Delayed_Encoder);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Encoding.Define_Screen
     (Delayed_Encoder, (Width => 1, Height => 1, others => <>));
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Encoding.Finish (Delayed_Encoder);
   Assert
     (Outcome.First_Error.Code = Giflib.Errors.Destination_Write_Failed
      and then Giflib.Encoding.State (Delayed_Encoder) = Giflib.Encoding.Failed,
      "flush Storage_Error escaped the encoder");
   Giflib.Encoding.Finalize (Delayed_Encoder);
end Destination_Exceptions_Are_Diagnostics;

