separate (Giflib.Testing.Test_Decoder)
procedure Expands_Frame_Rectangle_To_RGBA (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Fixture : aliased constant Giflib.Streams.Byte_Array :=
     [71, 73, 70, 56, 57, 97,
      2, 0, 1, 0, 16#80#, 0, 0,
      255, 0, 0, 0, 255, 0,
      16#21#, 16#F9#, 4, 1, 0, 0, 0, 0,
      16#2C#, 0, 0, 0, 0, 2, 0, 1, 0, 0,
      2, 2, 16#44#, 16#0A#, 0, 16#3B#];
   Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
   Decoder : Giflib.Decoding.Decoder (Source'Access);
   Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
   Header : Giflib.Decoding.Header_Info;
   Event : Giflib.Decoding.Decode_Event;
   Info : Giflib.Decoding.Frame_Info;
   RGBA : Giflib.Streams.Byte_Array (1 .. 8);
   Outcome : Giflib.Results.Result;
begin
   Options.Mode := Giflib.Decoding.Expanded_Frame;
   Giflib.Streams.Open (Source, Max_Transfer => 1);
   Outcome := Giflib.Decoding.Initialize (Decoder, Options);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Decode_Expanded_Frame (Decoder, RGBA, Info);
   Assert (Giflib.Results.Succeeded (Outcome)
           and then RGBA = [255, 0, 0, 0, 0, 255, 0, 255],
           "expanded RGBA frame or transparent alpha is wrong");
end Expands_Frame_Rectangle_To_RGBA;

