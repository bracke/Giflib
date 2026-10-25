separate (Giflib.Testing.Test_Decoder_Allocation)
procedure Decoder_Snapshot_Reuse
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Source : aliased Giflib.Streams.Memory_Source (Restore_Previous_Twice'Access);
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
   Assert (Giflib.Results.Succeeded (Outcome),
           "snapshot-reuse fixture header failed");
   for Frame in 1 .. 2 loop
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Giflib.Results.Succeeded (Outcome)
              and then Event.Kind = Giflib.Decoding.Extension_Event,
              "snapshot-reuse fixture control extension failed");
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Giflib.Results.Succeeded (Outcome)
              and then Event.Kind = Giflib.Decoding.Image_Event,
              "snapshot-reuse fixture did not reach image");
      if Frame = 2 then
         Giflib.Decoding.Testing.Inject_Storage_Error_After (Decoder);
      end if;
      Outcome := Giflib.Decoding.Decode_Composited_Frame (Decoder, Canvas, Info);
      Assert (Giflib.Results.Succeeded (Outcome),
              "same-sized restore frame allocated new snapshot storage");
   end loop;
   Finish_Scenario (Decoder);
exception
   when others =>
      Finish_Scenario (Decoder);
      raise;
end Decoder_Snapshot_Reuse;
