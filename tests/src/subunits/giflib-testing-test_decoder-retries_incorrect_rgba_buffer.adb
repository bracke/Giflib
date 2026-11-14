separate (Giflib.Testing.Test_Decoder)
procedure Retries_Incorrect_RGBA_Buffer
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Fixture : aliased constant Giflib.Streams.Byte_Array := One_Pixel_GIF;
   Outcome : Giflib.Results.Result;
begin
   for Mode in Giflib.Decoding.Expanded_Frame .. Giflib.Decoding.Composited_RGBA loop
      declare
         Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
         Decoder : Giflib.Decoding.Decoder (Source'Access);
         Options : Giflib.Decoding.Decode_Options :=
           Giflib.Decoding.Default_Options;
         Header : Giflib.Decoding.Header_Info;
         Event : Giflib.Decoding.Decode_Event;
         Info : Giflib.Decoding.Frame_Info;
         Wrong : Giflib.Streams.Byte_Array (1 .. 3);
         Correct : Giflib.Streams.Byte_Array (1 .. 4);
         Frame_Offset : Giflib.Source_Offset;
      begin
         Options.Mode := Mode;
         Giflib.Streams.Open (Source);
         Outcome := Giflib.Decoding.Initialize (Decoder, Options);
         Giflib.Testing.Assertions.Require_Success (Outcome);
         Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
         Giflib.Testing.Assertions.Require_Success (Outcome);
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
         Giflib.Testing.Assertions.Require_Success (Outcome);
         Frame_Offset := Source.Offset;
         if Mode = Giflib.Decoding.Expanded_Frame then
            Outcome := Giflib.Decoding.Decode_Expanded_Frame
              (Decoder, Wrong, Info);
         else
            Outcome := Giflib.Decoding.Decode_Composited_Frame
              (Decoder, Wrong, Info);
         end if;
         Assert
           (Outcome.First_Error.Code = Giflib.Errors.Buffer_Size_Mismatch
            and then Giflib.Decoding.State (Decoder) =
              Giflib.Decoding.Awaiting_Frame_Decision
            and then Source.Offset = Frame_Offset,
            "RGBA buffer mismatch was not retryable");
         if Mode = Giflib.Decoding.Expanded_Frame then
            Outcome := Giflib.Decoding.Decode_Expanded_Frame
              (Decoder, Correct, Info);
         else
            Outcome := Giflib.Decoding.Decode_Composited_Frame
              (Decoder, Correct, Info);
         end if;
         Assert
           (Giflib.Results.Succeeded (Outcome),
            "RGBA decode did not succeed after correcting its buffer");
      end;
   end loop;
end Retries_Incorrect_RGBA_Buffer;

