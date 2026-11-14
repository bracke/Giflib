separate (Giflib.Testing.Test_Encoding)
procedure Encodes_Independent_GIF87a_Still (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Storage : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 256 => 0];
   Destination : aliased Giflib.Streams.Fixed_Buffer_Destination (Storage'Access);
   Encoder : Giflib.Encoding.Encoder (Destination'Access);
   Options : Giflib.Encoding.Encode_Options := Giflib.Encoding.Default_Options;
   Frame : constant Giflib.Encoding.Frame_Info :=
     (Left => 0, Top => 0, Width => 2, Height => 1, others => <>);
   Outcome : Giflib.Results.Result;
   End_Offset : Giflib.Destination_Offset;
begin
   Options.Version := Giflib.Encoding.Force_GIF87a;
   Giflib.Streams.Open (Destination, Max_Transfer => 2);
   Outcome := Giflib.Encoding.Initialize (Encoder, Options);
   Assert (Giflib.Results.Succeeded (Outcome), "GIF87a encoder initialization failed");
   Outcome := Giflib.Encoding.Define_Screen (Encoder, (Width => 2, Height => 1, others => <>));
   Assert (Giflib.Results.Succeeded (Outcome), "GIF87a screen definition failed");
   Outcome := Giflib.Encoding.Set_Global_Palette (Encoder, BW_Palette);
   Assert (Giflib.Results.Succeeded (Outcome), "GIF87a global palette failed");
   Outcome := Giflib.Encoding.Add_Indexed_Frame
     (Encoder, Frame, Giflib.Encoding.Global_Frame_Palette, [0, 1]);
   Assert (Giflib.Results.Succeeded (Outcome), "GIF87a frame encode failed");
   Outcome := Giflib.Encoding.Finish (Encoder);
   Assert (Giflib.Results.Succeeded (Outcome), "GIF87a finish failed");
   End_Offset := Destination.Offset;
   Outcome := Giflib.Encoding.Finish (Encoder);
   Assert (Giflib.Results.Succeeded (Outcome) and then Destination.Offset = End_Offset,
           "repeated finish wrote a duplicate trailer");
   Assert (Storage (1 .. 6) = [71, 73, 70, 56, 55, 97], "GIF87a signature is wrong");

   declare
      Encoded : aliased constant Giflib.Streams.Byte_Array :=
        Storage (1 .. Natural (Destination.Offset));
      Source : aliased Giflib.Streams.Memory_Source (Encoded'Access);
      Decoder : Giflib.Decoding.Decoder (Source'Access);
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
      Info : Giflib.Decoding.Frame_Info;
      Pixels : Giflib.Streams.Byte_Array (1 .. 2);
   begin
      Giflib.Streams.Open (Source, Max_Transfer => 1);
      Outcome := Giflib.Decoding.Initialize (Decoder);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Assert (Giflib.Results.Succeeded (Outcome) and then Header.Version = Giflib.GIF87a,
              "independent decode rejected GIF87a output");
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixels, Info);
      Assert (Giflib.Results.Succeeded (Outcome) and then Pixels = [0, 1],
              "GIF87a output changed indexed pixels");
   end;
end Encodes_Independent_GIF87a_Still;

