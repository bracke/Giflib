separate (Giflib.Testing.Test_Encoding)
procedure Encodes_Truecolor_Local_And_Global (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   RGBA : aliased constant Giflib.Streams.Byte_Array :=
     [255, 0, 0, 0, 0, 255, 0, 255];
   View : constant Giflib.Images.Image_View :=
     (Format => Giflib.RGBA_32, Width => 2, Height => 1, Stride => 8,
      Accessible_Bytes => 8, Data => RGBA'Access);
   Storage : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 512 => 0];
   Destination : aliased Giflib.Streams.Fixed_Buffer_Destination (Storage'Access);
   Encoder : Giflib.Encoding.Encoder (Destination'Access);
   Outcome : Giflib.Results.Result;
begin
   Giflib.Streams.Open (Destination);
   Outcome := Giflib.Encoding.Initialize (Encoder);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Encoding.Define_Screen (Encoder, (Width => 2, Height => 1, others => <>));
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Encoding.Add_Truecolor_Frame
     (Encoder, (Width => 2, Height => 1, others => <>), View);
   Assert (Giflib.Results.Succeeded (Outcome), "local truecolor frame failed");
   Outcome := Giflib.Encoding.Finish (Encoder);
   Assert (Giflib.Results.Succeeded (Outcome), "local truecolor finish failed");
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
      Giflib.Streams.Open (Source);
      Outcome := Giflib.Decoding.Initialize (Decoder);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Giflib.Results.Succeeded (Outcome)
              and then Event.Kind = Giflib.Decoding.Extension_Event,
              "truecolor alpha did not emit a control extension");
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixels, Info);
      Assert (Giflib.Results.Succeeded (Outcome)
              and then Info.Has_Local_Palette
              and then Info.Control.Has_Transparency
              and then Pixels = [0, 1],
              "local truecolor indices/transparency changed after encoding");
   end;

   declare
      RGB : aliased constant Giflib.Streams.Byte_Array := [0, 0, 0, 255, 255, 255];
      RGB_View : constant Giflib.Images.Image_View :=
        (Format => Giflib.RGB_24, Width => 2, Height => 1, Stride => 6,
         Accessible_Bytes => 6, Data => RGB'Access);
      Global_Storage : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 512 => 0];
      Global_Destination : aliased Giflib.Streams.Fixed_Buffer_Destination (Global_Storage'Access);
      Global_Encoder : Giflib.Encoding.Encoder (Global_Destination'Access);
      Encode_Options : Giflib.Encoding.Encode_Options := Giflib.Encoding.Default_Options;
   begin
      Encode_Options.Truecolor_Palettes := Giflib.Encoding.Use_Existing_Global;
      Giflib.Streams.Open (Global_Destination);
      Outcome := Giflib.Encoding.Initialize
        (Global_Encoder, Encode_Options);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Encoding.Define_Screen
        (Global_Encoder, (Width => 2, Height => 1, others => <>));
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Encoding.Set_Global_Palette (Global_Encoder, BW_Palette);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Encoding.Add_Truecolor_Frame
        (Global_Encoder, (Width => 2, Height => 1, others => <>), RGB_View);
      Assert (Giflib.Results.Succeeded (Outcome), "global truecolor frame failed");
      Outcome := Giflib.Encoding.Finish (Global_Encoder);
      Assert (Giflib.Results.Succeeded (Outcome), "global truecolor finish failed");
      declare
         Encoded : aliased constant Giflib.Streams.Byte_Array :=
           Global_Storage (1 .. Natural (Global_Destination.Offset));
         Source : aliased Giflib.Streams.Memory_Source (Encoded'Access);
         Decoder : Giflib.Decoding.Decoder (Source'Access);
         Header : Giflib.Decoding.Header_Info;
         Event : Giflib.Decoding.Decode_Event;
         Info : Giflib.Decoding.Frame_Info;
         Pixels : Giflib.Streams.Byte_Array (1 .. 2);
      begin
         Giflib.Streams.Open (Source);
         Outcome := Giflib.Decoding.Initialize (Decoder);
         Giflib.Testing.Assertions.Require_Success (Outcome);
         Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
         Giflib.Testing.Assertions.Require_Success (Outcome);
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
         Giflib.Testing.Assertions.Require_Success (Outcome);
         Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixels, Info);
         Assert (Giflib.Results.Succeeded (Outcome)
                 and then not Info.Has_Local_Palette and then Pixels = [0, 1],
                 "existing-global truecolor strategy was not retained");
      end;
   end;

   declare
      RGB : aliased constant Giflib.Streams.Byte_Array := [0, 0, 0, 255, 255, 255];
      RGB_View : constant Giflib.Images.Image_View :=
        (Format => Giflib.RGB_24, Width => 2, Height => 1, Stride => 6,
         Accessible_Bytes => 6, Data => RGB'Access);
      Reuse_Storage : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 512 => 0];
      Reuse_Destination : aliased Giflib.Streams.Fixed_Buffer_Destination (Reuse_Storage'Access);
      Reuse_Encoder : Giflib.Encoding.Encoder (Reuse_Destination'Access);
      Encode_Options : Giflib.Encoding.Encode_Options := Giflib.Encoding.Default_Options;
   begin
      Encode_Options.Truecolor_Palettes := Giflib.Encoding.Reuse_Identical_Global;
      Giflib.Streams.Open (Reuse_Destination);
      Outcome := Giflib.Encoding.Initialize
        (Reuse_Encoder, Encode_Options);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Encoding.Define_Screen
        (Reuse_Encoder, (Width => 2, Height => 1, others => <>));
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Encoding.Set_Global_Palette (Reuse_Encoder, BW_Palette);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Encoding.Add_Truecolor_Frame
        (Reuse_Encoder, (Width => 2, Height => 1, others => <>), RGB_View);
      Assert (Giflib.Results.Succeeded (Outcome), "identical-global reuse frame failed");
      Outcome := Giflib.Encoding.Finish (Reuse_Encoder);
      Assert (Giflib.Results.Succeeded (Outcome), "identical-global reuse finish failed");
      declare
         Encoded : aliased constant Giflib.Streams.Byte_Array :=
           Reuse_Storage (1 .. Natural (Reuse_Destination.Offset));
         Source : aliased Giflib.Streams.Memory_Source (Encoded'Access);
         Decoder : Giflib.Decoding.Decoder (Source'Access);
         Header : Giflib.Decoding.Header_Info;
         Event : Giflib.Decoding.Decode_Event;
         Info : Giflib.Decoding.Frame_Info;
         Pixels : Giflib.Streams.Byte_Array (1 .. 2);
      begin
         Giflib.Streams.Open (Source);
         Outcome := Giflib.Decoding.Initialize (Decoder);
         Giflib.Testing.Assertions.Require_Success (Outcome);
         Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
         Giflib.Testing.Assertions.Require_Success (Outcome);
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
         Giflib.Testing.Assertions.Require_Success (Outcome);
         Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixels, Info);
         Assert (Giflib.Results.Succeeded (Outcome)
                 and then not Info.Has_Local_Palette and then Pixels = [0, 1],
                 "identical generated palette was not reused globally");
      end;
   end;
end Encodes_Truecolor_Local_And_Global;

