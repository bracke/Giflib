separate (Giflib.Testing.Test_Decoder_Allocation)
procedure Decoder_Cleanup_Failures
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Source : aliased Giflib.Streams.Memory_Source (Comment'Access);
   Decoder : Giflib.Decoding.Decoder (Source'Access);
   Header : Giflib.Decoding.Header_Info;
   Event : Giflib.Decoding.Decode_Event;
   Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
   Outcome : Giflib.Results.Result;
begin
   Options.Retention := Giflib.Metadata.Retain_All_Bounded;
   Options.Mode := Giflib.Decoding.Composited_RGBA;
   Start (Source, Decoder, Options);
   Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
   Assert (Giflib.Results.Succeeded (Outcome),
           "cleanup-fault decoder header failed");
   Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
   Assert
     (Giflib.Results.Succeeded (Outcome)
      and then Event.Kind = Giflib.Decoding.Extension_Event,
      "cleanup-fault decoder did not retain metadata");
   Giflib.Decoding.Testing.Corrupt_Allocation_Budget (Decoder);
   Outcome := Giflib.Decoding.Cancel (Decoder);
   Assert
     (Outcome.First_Error.Code = Giflib.Errors.Internal_Invariant_Failed
      and then Giflib.Decoding.Testing.Resources_Released (Decoder),
      "decoder cleanup failure retained owned storage");
   Finish_Scenario (Decoder);
exception
   when others =>
      Finish_Scenario (Decoder);
      raise;
end Decoder_Cleanup_Failures;
