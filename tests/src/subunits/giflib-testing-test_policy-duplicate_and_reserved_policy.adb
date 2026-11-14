separate (Giflib.Testing.Test_Policy)
procedure Duplicate_And_Reserved_Policy (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Fixture : aliased constant Giflib.Streams.Byte_Array :=
     [71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 16#80#, 0, 0,
      0, 0, 0, 255, 255, 255,
      16#21#, 16#F9#, 4, 4, 0, 0, 0, 0,
      16#21#, 16#F9#, 4, 16, 0, 0, 0, 0,
      16#2C#, 0, 0, 0, 0, 1, 0, 1, 0, 0,
      2, 2, 16#44#, 1, 0, 16#3B#];
   Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
   Decoder : Giflib.Decoding.Decoder (Source'Access);
   Header : Giflib.Decoding.Header_Info;
   Event : Giflib.Decoding.Decode_Event;
   Info : Giflib.Decoding.Frame_Info;
   Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
   Constraints : Giflib.Limits.Limit_Set := Giflib.Limits.Default_Limits;
   Canvas : Giflib.Streams.Byte_Array (1 .. 4);
   Warning : Giflib.Errors.Warning;
   Outcome : Giflib.Results.Result;
begin
   Giflib.Streams.Open (Source);
   Outcome := Giflib.Decoding.Initialize (Decoder);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Duplicate_Graphic_Control,
           "strict mode accepted duplicate GCE");

   Options.Mode := Giflib.Decoding.Composited_RGBA;
   Options.Strictness := Giflib.Compatible;
   Constraints.Max_Warning_Records := 1;
   Giflib.Streams.Open (Source);
   Outcome := Giflib.Decoding.Reset (Decoder, Options, Constraints);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Decode_Composited_Frame (Decoder, Canvas, Info);
   Assert (Giflib.Results.Succeeded (Outcome), "compatible reserved disposal failed");
   Assert (Info.Control.Disposal = 4, "raw reserved disposal value was lost");
   Assert (Giflib.Decoding.Warning_Count (Decoder) = 1, "warning limit was not enforced");
   Outcome := Giflib.Decoding.Warning_At (Decoder, 1, Warning);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Assert (Warning.Code = Giflib.Errors.Warnings_Suppressed,
           "overflowed warning buffer did not report suppression");

   Giflib.Decoding.Finalize (Decoder);
   Constraints.Max_Warning_Records := 0;
   Giflib.Streams.Open (Source);
   Outcome := Giflib.Decoding.Initialize
     (Decoder, Options, Constraints);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Assert (Giflib.Decoding.Warning_Count (Decoder) = 0,
           "diagnostic event budget was ignored");
end Duplicate_And_Reserved_Policy;
