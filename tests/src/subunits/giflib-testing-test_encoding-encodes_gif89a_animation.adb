separate (Giflib.Testing.Test_Encoding)
procedure Encodes_GIF89a_Animation (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Storage : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 1_024 => 0];
   Destination : aliased Giflib.Streams.Fixed_Buffer_Destination (Storage'Access);
   Encoder : Giflib.Encoding.Encoder (Destination'Access);
   First : Giflib.Encoding.Frame_Info :=
     (Left => 0, Top => 0, Width => 2, Height => 1, others => <>);
   Second : Giflib.Encoding.Frame_Info :=
     (Left => 0, Top => 0, Width => 2, Height => 1, Interlaced => True, others => <>);
   Local : Giflib.Palettes.Palette;
   Outcome : Giflib.Results.Result;
begin
   First.Control := (Disposal => 1, Delay_CS => 3, others => <>);
   Second.Control :=
     (Disposal => 2, Delay_CS => 0, Has_Transparency => True,
      Transparent_Index => 0, others => <>);
   Local.Length := 2;
   Local.Colors (0) := (255, 0, 0);
   Local.Colors (1) := (0, 255, 0);
   Giflib.Streams.Open (Destination, Max_Transfer => 3);
   Outcome := Giflib.Encoding.Initialize (Encoder);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Encoding.Define_Screen (Encoder, (Width => 2, Height => 1, others => <>));
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Encoding.Set_Global_Palette (Encoder, BW_Palette);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Encoding.Set_Loop_Count (Encoder, 0);
   Assert (Giflib.Results.Succeeded (Outcome), "loop definition failed");
   Outcome := Giflib.Encoding.Add_Indexed_Frame
     (Encoder, First, Giflib.Encoding.Global_Frame_Palette, [0, 1]);
   Assert (Giflib.Results.Succeeded (Outcome), "first animation frame failed");
   Outcome := Giflib.Encoding.Add_Indexed_Frame
     (Encoder, Second,
      (Selection => Giflib.Encoding.Use_Local_Palette, Value => Local), [1, 0]);
   Assert (Giflib.Results.Succeeded (Outcome), "second animation frame failed");
   Outcome := Giflib.Encoding.Finish (Encoder);
   Assert (Giflib.Results.Succeeded (Outcome), "animation finish failed");
   Assert (Storage (1 .. 6) = [71, 73, 70, 56, 57, 97], "GIF89a signature is wrong");

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
      Giflib.Streams.Open (Source, Max_Transfer => 2);
      Outcome := Giflib.Decoding.Initialize (Decoder);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Event.Extension.Loop_Info.Is_Loop
              and then Giflib.Decoding.Looping (Decoder).State = Giflib.Animations.Infinite_Looping,
              "encoded infinite loop was not preserved");
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixels, Info);
      Assert (Giflib.Results.Succeeded (Outcome) and then Pixels = [0, 1],
              "first encoded animation frame changed");
      Assert (Info.Control.Disposal = 1, "first disposal changed");
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixels, Info);
      Assert (Giflib.Results.Succeeded (Outcome) and then Pixels = [1, 0],
              "second encoded animation frame changed");
      Assert (Info.Interlaced and then Info.Has_Local_Palette, "encoded frame flags changed");
      Assert (Info.Control.Disposal = 2 and then Info.Control.Has_Transparency,
              "second frame control changed");
   end;
end Encodes_GIF89a_Animation;

