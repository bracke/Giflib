separate (Giflib.Testing.Test_Decoder_Allocation)
procedure Decoder_Core_Allocation_Failures
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Source : aliased Giflib.Streams.Memory_Source (Plain'Access);
   Decoder : Giflib.Decoding.Decoder (Source'Access);
   Header : Giflib.Decoding.Header_Info;
   Event : Giflib.Decoding.Decode_Event;
   Info : Giflib.Decoding.Frame_Info;
   Canvas : Giflib.Streams.Byte_Array (1 .. 4);
   Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
   Outcome : Giflib.Results.Result;
begin
   Start (Source, Decoder, Options);
   Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
   Assert (Giflib.Results.Succeeded (Outcome),
           "LZW-workspace fixture header failed");
   Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
   Assert (Giflib.Results.Succeeded (Outcome)
           and then Event.Kind = Giflib.Decoding.Image_Event,
           "LZW-workspace fixture did not reach its image");
   Giflib.Decoding.Testing.Inject_Storage_Error_After (Decoder);
   Outcome := Giflib.Decoding.Decode_Indexed_Frame
     (Decoder, Canvas (1 .. 1), Info);
   Require_Allocation_Failure
     (Outcome, "decoder LZW-workspace Storage_Error escaped");
   Assert (Giflib.Decoding.Testing.Allocated_Bytes (Decoder) = 0,
           "failed decoder LZW allocation retained its budget charge");
   Finish_Scenario (Decoder);

   Options.Mode := Giflib.Decoding.Composited_RGBA;
   Start (Source, Decoder, Options);
   Giflib.Decoding.Testing.Inject_Storage_Error_After (Decoder);
   Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
   Require_Allocation_Failure (Outcome, "canvas Storage_Error escaped");
   Assert (Giflib.Decoding.State (Decoder) = Giflib.Decoding.Failed,
           "canvas allocation failure did not fail the decoder");
   Finish_Scenario (Decoder);
exception
   when others =>
      Finish_Scenario (Decoder);
      raise;
end Decoder_Core_Allocation_Failures;
