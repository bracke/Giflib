separate (Giflib.Testing.Test_Policy)
procedure Image_Descriptor_Reserved_Policy
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Fixture : aliased constant Giflib.Streams.Byte_Array :=
     [71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 16#80#, 0, 0,
      0, 0, 0, 255, 255, 255,
      16#2C#, 0, 0, 0, 0, 1, 0, 1, 0, 16#08#,
      2, 2, 16#44#, 1, 0, 16#3B#];
   Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
   Decoder : Giflib.Decoding.Decoder (Source'Access);
   Header : Giflib.Decoding.Header_Info;
   Event : Giflib.Decoding.Decode_Event;
   Info : Giflib.Decoding.Frame_Info;
   Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
   Pixel : Giflib.Streams.Byte_Array (1 .. 1);
   Warning : Giflib.Errors.Warning;
   Outcome : Giflib.Results.Result;
begin
   Giflib.Streams.Open (Source);
   Outcome := Giflib.Decoding.Initialize (Decoder);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_Block,
           "strict mode accepted reserved image-descriptor bits");
   Assert
     (Outcome.First_Error.Context.Block = Giflib.Image_Descriptor_Block
      and then Outcome.First_Error.Context.Source_Position.Value = 28
      and then Outcome.First_Error.Context.Actual = 8,
      "reserved image-descriptor diagnostic context is wrong");

   Options.Strictness := Giflib.Compatible;
   Giflib.Streams.Open (Source);
   Outcome := Giflib.Decoding.Reset
     (Decoder, Options);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixel, Info);
   Assert
     (Giflib.Results.Succeeded (Outcome) and then Pixel = [0],
      "compatible mode rejected reserved image-descriptor bits");
   Assert
     (Giflib.Decoding.Warning_Count (Decoder) = 1,
      "compatible reserved image-descriptor warning was not recorded");
   Outcome := Giflib.Decoding.Warning_At (Decoder, 1, Warning);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Assert
     (Warning.Code = Giflib.Errors.Reserved_Value_Accepted
      and then Warning.Context.Block = Giflib.Image_Descriptor_Block
      and then Warning.Context.Source_Position.Value = 28
      and then Warning.Context.Actual = 8,
      "compatible reserved image-descriptor warning context is wrong");
end Image_Descriptor_Reserved_Policy;
