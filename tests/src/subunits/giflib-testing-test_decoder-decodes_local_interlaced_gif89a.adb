separate (Giflib.Testing.Test_Decoder)
procedure Decodes_Local_Interlaced_GIF89a (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Fixture : aliased constant Giflib.Streams.Byte_Array :=
     [71, 73, 70, 56, 57, 97,
      2, 0, 4, 0, 0, 0, 0,
      16#2C#, 0, 0, 0, 0, 2, 0, 4, 0, 16#C2#,
      0, 0, 0, 32, 0, 0, 64, 0, 0, 96, 0, 0,
      128, 0, 0, 160, 0, 0, 192, 0, 0, 224, 0, 0,
      3, 6, 8, 33, 67, 101, 39, 1, 0,
      16#3B#];
   Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
   Decoder : Giflib.Decoding.Decoder (Source'Access);
   Header : Giflib.Decoding.Header_Info;
   Event : Giflib.Decoding.Decode_Event;
   Info : Giflib.Decoding.Frame_Info;
   Pixels : Giflib.Streams.Byte_Array (1 .. 8);
   Outcome : Giflib.Results.Result;
begin
   Giflib.Streams.Open (Source, Max_Transfer => 2);
   Outcome := Giflib.Decoding.Initialize (Decoder);
   Assert (Giflib.Results.Succeeded (Outcome), "GIF89a initialization failed");
   Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
   Assert (Giflib.Results.Succeeded (Outcome) and then Header.Version = Giflib.GIF89a,
           "GIF89a header failed");
   Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
   Assert (Giflib.Results.Succeeded (Outcome), "GIF89a image event failed");
   Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixels, Info);
   Assert (Giflib.Results.Succeeded (Outcome), "local interlaced GIF failed");
   Assert (Info.Interlaced and then Info.Has_Local_Palette, "frame flags were lost");
   Assert (Info.Effective_Palette.Length = 8, "local palette was not surfaced");
   Assert (Pixels = [0, 1, 4, 5, 2, 3, 6, 7], "interlaced public pixels are wrong");
end Decodes_Local_Interlaced_GIF89a;
