separate (Giflib.Testing.Test_Encoding)
procedure Preserves_Extension_Payload_And_Placement (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Storage : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 1_024 => 0];
   Destination : aliased Giflib.Streams.Fixed_Buffer_Destination (Storage'Access);
   Encoder : Giflib.Encoding.Encoder (Destination'Access);
   Frame : constant Giflib.Encoding.Frame_Info := (others => <>);
   Extension : constant Giflib.Metadata.Extension_Info :=
     (Kind => Giflib.Metadata.Comment_Extension, others => <>);
   Large_Payload : constant Giflib.Streams.Byte_Array :=
     [for I in 1 .. 300 => Giflib.Byte ((I - 1) mod 256)];
   Outcome : Giflib.Results.Result;
begin
   Giflib.Streams.Open (Destination);
   Outcome := Giflib.Encoding.Initialize (Encoder);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Encoding.Define_Screen (Encoder, (others => <>));
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Encoding.Set_Global_Palette (Encoder, BW_Palette);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Encoding.Add_Indexed_Frame
     (Encoder, Frame, Giflib.Encoding.Global_Frame_Palette, [0]);
   Assert (Giflib.Results.Succeeded (Outcome), "pre-extension frame failed");
   Outcome := Giflib.Encoding.Add_Decoded_Extension_Exact
     (Encoder, Extension, [65, 66, 67, 68, 69], [3, 2]);
   Assert (Giflib.Results.Succeeded (Outcome), "exact comment encode failed");
   Outcome := Giflib.Encoding.Add_Decoded_Extension
     (Encoder, Extension, Large_Payload);
   Assert (Giflib.Results.Succeeded (Outcome), "automatic comment chunking failed");
   Outcome := Giflib.Encoding.Add_Indexed_Frame
     (Encoder, Frame, Giflib.Encoding.Global_Frame_Palette, [1]);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Encoding.Finish (Encoder);
   Assert (Giflib.Results.Succeeded (Outcome), "extension fixture finish failed");
   declare
      Encoded : aliased constant Giflib.Streams.Byte_Array :=
        Storage (1 .. Natural (Destination.Offset));
      Source : aliased Giflib.Streams.Memory_Source (Encoded'Access);
      Decoder : Giflib.Decoding.Decoder (Source'Access);
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
      Info : Giflib.Decoding.Frame_Info;
      Decode_Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
      Pixel : Giflib.Streams.Byte_Array (1 .. 1);
      Payload : Giflib.Streams.Byte_Array (1 .. 5);
      Large_Copy : Giflib.Streams.Byte_Array (1 .. Large_Payload'Length);
      Count : Giflib.Byte_Count;
      Chunk_Count : Natural;
   begin
      Decode_Options.Retention := Giflib.Metadata.Retain_All_Exact_Bounded;
      Giflib.Streams.Open (Source);
      Outcome := Giflib.Decoding.Initialize (Decoder, Decode_Options);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixel, Info);
      Assert (Giflib.Results.Succeeded (Outcome) and then Pixel = [0],
              "first placement frame changed");
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Giflib.Results.Succeeded (Outcome)
              and then Event.Extension.Before_Frame = 1,
              "extension placement changed");
      Outcome := Giflib.Decoding.Retained_Extension_Chunk_Count (Decoder, 1, Chunk_Count);
      Assert (Giflib.Results.Succeeded (Outcome) and then Chunk_Count = 2,
              "extension chunk partition changed");
      Outcome := Giflib.Decoding.Copy_Retained_Extension_Payload
        (Decoder, 1, Payload, Count);
      Assert (Giflib.Results.Succeeded (Outcome)
              and then Payload = [65, 66, 67, 68, 69],
              "extension payload changed");
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Giflib.Results.Succeeded (Outcome)
              and then Event.Extension.Before_Frame = 1,
              "automatically chunked extension placement changed");
      Outcome := Giflib.Decoding.Retained_Extension_Chunk_Count
        (Decoder, 2, Chunk_Count);
      Assert (Giflib.Results.Succeeded (Outcome) and then Chunk_Count = 2,
              "automatic extension chunk count is wrong");
      Outcome := Giflib.Decoding.Copy_Retained_Extension_Payload
        (Decoder, 2, Large_Copy, Count);
      Assert (Giflib.Results.Succeeded (Outcome)
              and then Count = Giflib.Byte_Count (Large_Payload'Length)
              and then Large_Copy = Large_Payload,
              "automatically chunked extension payload changed");
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixel, Info);
      Assert (Giflib.Results.Succeeded (Outcome) and then Pixel = [1],
              "second placement frame changed");
   end;
end Preserves_Extension_Payload_And_Placement;
