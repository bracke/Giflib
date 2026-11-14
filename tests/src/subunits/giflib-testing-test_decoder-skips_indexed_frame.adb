separate (Giflib.Testing.Test_Decoder)
procedure Skips_Indexed_Frame (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Fixture : aliased constant Giflib.Streams.Byte_Array := One_Pixel_GIF;
   Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
   Decoder : Giflib.Decoding.Decoder (Source'Access);
   Header : Giflib.Decoding.Header_Info;
   Event : Giflib.Decoding.Decode_Event;
   Outcome : Giflib.Results.Result;
begin
   Giflib.Streams.Open (Source, Max_Transfer => 1);
   Outcome := Giflib.Decoding.Initialize (Decoder);
   Assert (Giflib.Results.Succeeded (Outcome), "skip fixture initialization failed");
   Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
   Assert (Giflib.Results.Succeeded (Outcome), "skip fixture header failed");
   Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
   Assert (Giflib.Results.Succeeded (Outcome), "skip fixture image event failed");
   Outcome := Giflib.Decoding.Skip_Frame (Decoder);
   Assert (Giflib.Results.Succeeded (Outcome), "indexed frame skip failed");
   Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
   Assert (Giflib.Results.Succeeded (Outcome) and then Event.Kind = Giflib.Decoding.End_Event,
           "skip did not preserve next block boundary");
end Skips_Indexed_Frame;

