separate (Giflib.Testing.Test_Decoder)
procedure Retries_Incorrect_Indexed_Buffer
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Fixture : aliased constant Giflib.Streams.Byte_Array := One_Pixel_GIF;
   Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
   Decoder : Giflib.Decoding.Decoder (Source'Access);
   Header : Giflib.Decoding.Header_Info;
   Event : Giflib.Decoding.Decode_Event;
   Info : Giflib.Decoding.Frame_Info;
   Wrong : Giflib.Streams.Byte_Array (1 .. 2);
   Correct : Giflib.Streams.Byte_Array (1 .. 1);
   Frame_Offset : Giflib.Source_Offset;
   Outcome : Giflib.Results.Result;
begin
   Giflib.Streams.Open (Source);
   Outcome := Giflib.Decoding.Initialize (Decoder);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Frame_Offset := Source.Offset;
   Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Wrong, Info);
   Assert
     (Outcome.First_Error.Code = Giflib.Errors.Buffer_Size_Mismatch
      and then Giflib.Decoding.State (Decoder) =
        Giflib.Decoding.Awaiting_Frame_Decision
      and then Source.Offset = Frame_Offset,
      "raw buffer mismatch was not retryable");
   Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Correct, Info);
   Assert
     (Giflib.Results.Succeeded (Outcome) and then Correct = [0],
      "raw decode did not succeed after correcting its buffer");
end Retries_Incorrect_Indexed_Buffer;

