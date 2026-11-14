separate (Giflib.Testing.Test_Decoder)
procedure Decodes_Independent_One_Pixel_GIF (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Fixture : aliased constant Giflib.Streams.Byte_Array := One_Pixel_GIF;
   Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
   Decoder : Giflib.Decoding.Decoder (Source'Access);
   Header : Giflib.Decoding.Header_Info;
   Event : Giflib.Decoding.Decode_Event;
   Info : Giflib.Decoding.Frame_Info;
   Pixels : Giflib.Streams.Byte_Array (1 .. 1);
   Outcome : Giflib.Results.Result;
   End_Offset : Giflib.Source_Offset;
begin
   Giflib.Streams.Open (Source, Max_Transfer => 1);
   Outcome := Giflib.Decoding.Initialize (Decoder);
   Assert (Giflib.Results.Succeeded (Outcome), "decoder initialization failed");
   Assert (Giflib.Decoding.State (Decoder) = Giflib.Decoding.Initialized, "wrong initialized state");

   Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
   Assert (Giflib.Results.Succeeded (Outcome), "public header read failed");
   Assert (Header.Version = Giflib.GIF87a and then Header.Width = 1 and then Header.Height = 1,
           "public header is wrong");

   Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
   Assert (Giflib.Results.Succeeded (Outcome) and then Event.Kind = Giflib.Decoding.Image_Event,
           "image event was not reported");
   Assert
     (Event.Left = 0 and then Event.Top = 0
      and then Event.Width = 1 and then Event.Height = 1
      and then not Event.Interlaced
      and then Event.Indexed_Bytes = 1
      and then Event.Expanded_Bytes = 4,
      "image event did not expose exact prepared-frame geometry");
   Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixels, Info);
   Assert (Giflib.Results.Succeeded (Outcome), "public indexed decode failed");
   Assert (Pixels = [0] and then Info.Ordinal = 0, "public indexed frame is wrong");

   Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
   Assert (Giflib.Results.Succeeded (Outcome) and then Event.Kind = Giflib.Decoding.End_Event,
           "end event was not reported");
   End_Offset := Source.Offset;
   Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
   Assert (Giflib.Results.Succeeded (Outcome) and then Source.Offset = End_Offset,
           "repeated completion consumed source bytes");
   Giflib.Decoding.Finalize (Decoder);
   Giflib.Decoding.Finalize (Decoder);
   Assert (Giflib.Decoding.State (Decoder) = Giflib.Decoding.Finalized,
           "finalization is not idempotent");
end Decodes_Independent_One_Pixel_GIF;

