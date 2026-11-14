separate (Giflib.Testing.Test_Decoder)
procedure Rejects_Constrained_Event
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Fixture : aliased constant Giflib.Streams.Byte_Array :=
     [71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 0, 0, 0, 16#3B#];
   Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
   Decoder : Giflib.Decoding.Decoder (Source'Access);
   Header : Giflib.Decoding.Header_Info;
   Event : Giflib.Decoding.Decode_Event
     (Kind => Giflib.Decoding.Image_Event);
   Outcome : Giflib.Results.Result;
begin
   Giflib.Streams.Open (Source);
   Outcome := Giflib.Decoding.Initialize (Decoder);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
   Assert
     (Outcome.First_Error.Code = Giflib.Errors.Output_Variant_Mismatch,
      "constrained event output raised or accepted the wrong variant");
end Rejects_Constrained_Event;

