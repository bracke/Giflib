separate (Giflib.Testing.Test_Extensions)
procedure Plain_Text_Consumes_GCE (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Fixture : aliased constant Giflib.Streams.Byte_Array :=
     Header_With_Palette &
     [16#21#, 16#F9#, 4, 4, 0, 0, 0, 0] &
     [16#21#, 16#01#, 12, 0, 0, 0, 0, 1, 0, 1, 0, 8, 8, 1, 0, 1, 88, 0] &
     Image_1x1 & [16#3B#];
   Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
   Decoder : Giflib.Decoding.Decoder (Source'Access);
   Header : Giflib.Decoding.Header_Info;
   Event : Giflib.Decoding.Decode_Event;
   Info : Giflib.Decoding.Frame_Info;
   Pixel : Giflib.Streams.Byte_Array (1 .. 1);
   Outcome : Giflib.Results.Result;
begin
   Giflib.Streams.Open (Source);
   Outcome := Giflib.Decoding.Initialize (Decoder);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
   Assert (Giflib.Results.Succeeded (Outcome), "plain-text GCE failed");
   Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
   Assert (Giflib.Results.Succeeded (Outcome)
           and then Event.Extension.Kind = Giflib.Metadata.Plain_Text_Extension,
           "plain-text event failed");
   Assert (Event.Extension.Plain_Text.Grid_Width = 1
           and then Event.Extension.Plain_Text.Grid_Height = 1
           and then Event.Extension.Plain_Text.Cell_Width = 8
           and then Event.Extension.Plain_Text.Cell_Height = 8
           and then Event.Extension.Plain_Text.Foreground_Index = 1,
           "plain-text event did not surface parsed header fields");
   Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
   Assert (Giflib.Results.Succeeded (Outcome), "image event after plain text failed");
   Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixel, Info);
   Assert (Giflib.Results.Succeeded (Outcome), "image after plain text failed");
   Assert (Info.Control = Giflib.Frames.Default_Control,
           "plain text did not consume pending GCE");
end Plain_Text_Consumes_GCE;
