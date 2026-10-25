separate (Giflib.Testing.Test_Decoder_Allocation)
procedure Decoder_Snapshot_Allocation_Failures
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Source : aliased Giflib.Streams.Memory_Source (Restore_Previous'Access);
   Decoder : Giflib.Decoding.Decoder (Source'Access);
   Header : Giflib.Decoding.Header_Info;
   Event : Giflib.Decoding.Decode_Event;
   Info : Giflib.Decoding.Frame_Info;
   Canvas : Giflib.Streams.Byte_Array (1 .. 4);
   Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
   Outcome : Giflib.Results.Result;
begin
   Options.Mode := Giflib.Decoding.Composited_RGBA;
   Start (Source, Decoder, Options);
   Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
   Assert (Giflib.Results.Succeeded (Outcome), "snapshot fixture header failed");
   Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
   Assert (Giflib.Results.Succeeded (Outcome)
           and then Event.Kind = Giflib.Decoding.Extension_Event,
           "snapshot fixture control extension failed");
   Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
   Assert (Giflib.Results.Succeeded (Outcome)
           and then Event.Kind = Giflib.Decoding.Image_Event,
           "snapshot allocation fixture did not reach its image");
   Giflib.Decoding.Testing.Inject_Storage_Error_After (Decoder);
   Outcome := Giflib.Decoding.Decode_Composited_Frame (Decoder, Canvas, Info);
   Require_Allocation_Failure (Outcome, "snapshot Storage_Error escaped");
   Finish_Scenario (Decoder);
exception
   when others =>
      Finish_Scenario (Decoder);
      raise;
end Decoder_Snapshot_Allocation_Failures;
