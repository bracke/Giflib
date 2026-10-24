separate (Giflib.Testing.Test_Encoding)
procedure Independent_Encoders_Interleave
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Storage_A : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 256 => 0];
   Storage_B : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 256 => 0];
   Destination_A : aliased Giflib.Streams.Fixed_Buffer_Destination (Storage_A'Access);
   Destination_B : aliased Giflib.Streams.Fixed_Buffer_Destination (Storage_B'Access);
   Encoder_A : Giflib.Encoding.Encoder (Destination_A'Access);
   Encoder_B : Giflib.Encoding.Encoder (Destination_B'Access);
   Outcome_A : Giflib.Results.Result;
   Outcome_B : Giflib.Results.Result;
begin
   Giflib.Streams.Open (Destination_A,
                        Max_Transfer => 1);
   Giflib.Streams.Open (Destination_B,
                        Max_Transfer => 3);
   Outcome_A := Giflib.Encoding.Initialize
     (Encoder_A);
   Outcome_B := Giflib.Encoding.Initialize
     (Encoder_B);
   Assert (Giflib.Results.Succeeded (Outcome_A)
           and then Giflib.Results.Succeeded (Outcome_B),
           "independent encoder initialization failed");

   Outcome_A := Giflib.Encoding.Define_Screen
     (Encoder_A, (Width => 1, Height => 1, others => <>));
   Outcome_B := Giflib.Encoding.Define_Screen
     (Encoder_B, (Width => 2, Height => 1, others => <>));
   Assert (Giflib.Results.Succeeded (Outcome_A)
           and then Giflib.Results.Succeeded (Outcome_B),
           "interleaved screen definition failed");
   Outcome_A := Giflib.Encoding.Set_Global_Palette (Encoder_A, BW_Palette);
   Outcome_B := Giflib.Encoding.Set_Global_Palette (Encoder_B, BW_Palette);
   Assert (Giflib.Results.Succeeded (Outcome_A)
           and then Giflib.Results.Succeeded (Outcome_B),
           "interleaved encoder setup failed");

   Outcome_B := Giflib.Encoding.Add_Indexed_Frame
     (Encoder_B, (Width => 2, Height => 1, others => <>),
      Giflib.Encoding.Use_Global_Palette, (others => <>), [1, 0]);
   Outcome_A := Giflib.Encoding.Add_Indexed_Frame
     (Encoder_A, (Width => 1, Height => 1, others => <>),
      Giflib.Encoding.Use_Global_Palette, (others => <>), [0]);
   Assert (Giflib.Results.Succeeded (Outcome_A)
           and then Giflib.Results.Succeeded (Outcome_B),
           "interleaved frame encoding failed");

   Outcome_A := Giflib.Encoding.Finish (Encoder_A);
   Outcome_B := Giflib.Encoding.Finish (Encoder_B);
   Assert (Giflib.Results.Succeeded (Outcome_A)
           and then Giflib.Results.Succeeded (Outcome_B)
           and then Giflib.Encoding.State (Encoder_A) = Giflib.Encoding.Completed
           and then Giflib.Encoding.State (Encoder_B) = Giflib.Encoding.Completed,
           "independent encoders did not complete separately");

   declare
      Encoded_A : aliased constant Giflib.Streams.Byte_Array :=
        Storage_A (1 .. Natural (Destination_A.Offset));
      Encoded_B : aliased constant Giflib.Streams.Byte_Array :=
        Storage_B (1 .. Natural (Destination_B.Offset));
      Source_A : aliased Giflib.Streams.Memory_Source (Encoded_A'Access);
      Source_B : aliased Giflib.Streams.Memory_Source (Encoded_B'Access);
      Decoder_A : Giflib.Decoding.Decoder (Source_A'Access);
      Decoder_B : Giflib.Decoding.Decoder (Source_B'Access);
      Header_A : Giflib.Decoding.Header_Info;
      Header_B : Giflib.Decoding.Header_Info;
      Event_A : Giflib.Decoding.Decode_Event;
      Event_B : Giflib.Decoding.Decode_Event;
      Info_A : Giflib.Decoding.Frame_Info;
      Info_B : Giflib.Decoding.Frame_Info;
      Pixel_A : Giflib.Streams.Byte_Array (1 .. 1);
      Pixels_B : Giflib.Streams.Byte_Array (1 .. 2);
   begin
      Giflib.Streams.Open (Source_A,
                           Max_Transfer => 2);
      Giflib.Streams.Open (Source_B,
                           Max_Transfer => 1);
      Outcome_A := Giflib.Decoding.Initialize
        (Decoder_A);
      Outcome_B := Giflib.Decoding.Initialize
        (Decoder_B);
      Assert (Giflib.Results.Succeeded (Outcome_A)
              and then Giflib.Results.Succeeded (Outcome_B),
              "interleaved output decoder initialization failed");
      Outcome_B := Giflib.Decoding.Read_Header (Decoder_B, Header_B);
      Outcome_A := Giflib.Decoding.Read_Header (Decoder_A, Header_A);
      Assert (Giflib.Results.Succeeded (Outcome_A)
              and then Giflib.Results.Succeeded (Outcome_B)
              and then Header_A.Width = 1
              and then Header_B.Width = 2,
              "interleaved encoder outputs shared screen state");
      Outcome_A := Giflib.Decoding.Next_Event (Decoder_A, Event_A);
      Outcome_B := Giflib.Decoding.Next_Event (Decoder_B, Event_B);
      Assert (Giflib.Results.Succeeded (Outcome_A)
              and then Giflib.Results.Succeeded (Outcome_B)
              and then Event_A.Kind = Giflib.Decoding.Image_Event
              and then Event_B.Kind = Giflib.Decoding.Image_Event,
              "interleaved output image events failed");
      Outcome_B := Giflib.Decoding.Decode_Indexed_Frame
        (Decoder_B, Pixels_B, Info_B);
      Outcome_A := Giflib.Decoding.Decode_Indexed_Frame
        (Decoder_A, Pixel_A, Info_A);
      Assert (Giflib.Results.Succeeded (Outcome_A)
              and then Giflib.Results.Succeeded (Outcome_B)
              and then Pixel_A = [0]
              and then Pixels_B = [1, 0],
              "interleaved encoder outputs shared frame state");
   end;
end Independent_Encoders_Interleave;

