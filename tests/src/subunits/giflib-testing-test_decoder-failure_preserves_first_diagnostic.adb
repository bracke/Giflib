separate (Giflib.Testing.Test_Decoder)
procedure Failure_Preserves_First_Diagnostic (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Fixture : aliased constant Giflib.Streams.Byte_Array :=
     [71, 73, 70, 56, 57, 97,
      1, 0, 1, 0, 16#80#, 0, 0, 0, 0, 0, 255, 255, 255,
      16#2C#, 0, 0, 0, 0, 1, 0, 1, 0, 0,
      2, 2, 16#C4#, 16#0B#, 0, 16#3B#];
   Bad_Signature : aliased constant Giflib.Streams.Byte_Array :=
     [0, 73, 70, 56, 57, 97];
   Bad_Marker : aliased constant Giflib.Streams.Byte_Array :=
     [71, 73, 70, 56, 57, 97,
      1, 0, 1, 0, 0, 0, 0,
      0];
   Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
   Bad_Source : aliased Giflib.Streams.Memory_Source (Bad_Signature'Access);
   Marker_Source : aliased Giflib.Streams.Memory_Source (Bad_Marker'Access);
   Decoder : Giflib.Decoding.Decoder (Source'Access);
   Bad_Decoder : Giflib.Decoding.Decoder (Bad_Source'Access);
   Marker_Decoder : Giflib.Decoding.Decoder (Marker_Source'Access);
   Header : Giflib.Decoding.Header_Info;
   Event : Giflib.Decoding.Decode_Event;
   Info : Giflib.Decoding.Frame_Info;
   Pixel : Giflib.Streams.Byte_Array (1 .. 1);
   Outcome : Giflib.Results.Result;
begin
   Giflib.Streams.Open (Source);
   Outcome := Giflib.Decoding.Initialize (Decoder);
   Assert (Giflib.Results.Succeeded (Outcome), "malformed fixture initialization failed");
   Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
   Assert (Giflib.Results.Succeeded (Outcome), "malformed fixture header failed");
   Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
   Assert (Giflib.Results.Succeeded (Outcome), "malformed fixture image event failed");
   Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixel, Info);
   Assert (Outcome.First_Error.Code = Giflib.Errors.LZW_Invalid_Code,
           "malformed LZW has wrong public error");
   Assert (Giflib.Decoding.State (Decoder) = Giflib.Decoding.Failed,
           "fatal data error did not fail decoder");
   Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_State,
           "invalid transition has wrong immediate error");
   Assert (Giflib.Decoding.First_Error (Decoder).Code = Giflib.Errors.LZW_Invalid_Code,
           "first fatal diagnostic was overwritten");
   Giflib.Streams.Open (Bad_Source);
   Outcome := Giflib.Decoding.Initialize (Bad_Decoder);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Read_Header (Bad_Decoder, Header);
   Assert
     (Outcome.First_Error.Code = Giflib.Errors.Invalid_Signature
      and then Outcome.First_Error.Context.Source_Position.State =
        Giflib.Errors.Position_Available
      and then Outcome.First_Error.Context.Source_Position.Value = 0
      and then not Outcome.First_Error.Context.Frame.Present,
      "zero-offset signature diagnostic was overwritten by decoder context");

   Giflib.Streams.Open (Marker_Source);
   Outcome := Giflib.Decoding.Initialize (Marker_Decoder);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Read_Header (Marker_Decoder, Header);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Next_Event (Marker_Decoder, Event);
   Assert
     (Outcome.First_Error.Code = Giflib.Errors.Invalid_Block
      and then Outcome.First_Error.Context.Source_Position.State =
        Giflib.Errors.Position_Available
      and then Outcome.First_Error.Context.Source_Position.Value = 13,
      "invalid top-level marker was not rejected by the decoder");
end Failure_Preserves_First_Diagnostic;
