separate (Giflib.Testing.Test_Decoder)
procedure Independent_Decoders_Interleave (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   First_Fixture : aliased constant Giflib.Streams.Byte_Array := One_Pixel_GIF;
   Second_Fixture : aliased constant Giflib.Streams.Byte_Array :=
     [71, 73, 70, 56, 55, 97,
      1, 0, 1, 0, 16#80#, 0, 0,
      0, 0, 0, 255, 255, 255,
      16#2C#, 0, 0, 0, 0, 1, 0, 1, 0, 0,
      2, 2, 16#4C#, 16#01#, 0, 16#3B#];
   First_Source : aliased Giflib.Streams.Memory_Source (First_Fixture'Access);
   Second_Source : aliased Giflib.Streams.Memory_Source (Second_Fixture'Access);
   First_Decoder : Giflib.Decoding.Decoder (First_Source'Access);
   Second_Decoder : Giflib.Decoding.Decoder (Second_Source'Access);
   First_Header, Second_Header : Giflib.Decoding.Header_Info;
   First_Event, Second_Event : Giflib.Decoding.Decode_Event;
   First_Info, Second_Info : Giflib.Decoding.Frame_Info;
   First_Pixel, Second_Pixel : Giflib.Streams.Byte_Array (1 .. 1);
   Outcome : Giflib.Results.Result;
begin
   Giflib.Streams.Open (First_Source, Max_Transfer => 1);
   Giflib.Streams.Open (Second_Source, Max_Transfer => 2);
   Outcome := Giflib.Decoding.Initialize (First_Decoder);
   Assert (Giflib.Results.Succeeded (Outcome), "first independent decoder failed to initialize");
   Outcome := Giflib.Decoding.Initialize (Second_Decoder);
   Assert (Giflib.Results.Succeeded (Outcome), "second independent decoder failed to initialize");
   Outcome := Giflib.Decoding.Read_Header (First_Decoder, First_Header);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Read_Header (Second_Decoder, Second_Header);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Next_Event (First_Decoder, First_Event);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Next_Event (Second_Decoder, Second_Event);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Decode_Indexed_Frame (Second_Decoder, Second_Pixel, Second_Info);
   Assert (Giflib.Results.Succeeded (Outcome) and then Second_Pixel = [1],
           "second decoder state leaked or changed");
   Outcome := Giflib.Decoding.Decode_Indexed_Frame (First_Decoder, First_Pixel, First_Info);
   Assert (Giflib.Results.Succeeded (Outcome) and then First_Pixel = [0],
           "first decoder state leaked or changed");
end Independent_Decoders_Interleave;

