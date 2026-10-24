with Ada.Text_IO;

with Giflib;
with Giflib.Encoding;
with Giflib.Palettes;
with Giflib.Results;
with Giflib.Streams;

procedure Encode_Still is
   Storage : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 1_024 => 0];
   Destination : aliased Giflib.Streams.Fixed_Buffer_Destination (Storage'Access);
   Encoder : Giflib.Encoding.Encoder (Destination'Access);
   Palette : Giflib.Palettes.Palette;
   Outcome : Giflib.Results.Result;

   procedure Require_Success is
   begin
      if not Giflib.Results.Succeeded (Outcome) then
         raise Program_Error with "GIF encoding failed";
      end if;
   end Require_Success;
begin
   Palette.Length := 2;
   Palette.Colors (0) := (0, 0, 0);
   Palette.Colors (1) := (255, 255, 255);

   Giflib.Streams.Open (Destination);
   Outcome := Giflib.Encoding.Initialize (Encoder);
   Require_Success;
   Outcome := Giflib.Encoding.Define_Screen
     (Encoder, (Width => 2, Height => 2, others => <>));
   Require_Success;
   Outcome := Giflib.Encoding.Set_Global_Palette (Encoder, Palette);
   Require_Success;
   Outcome := Giflib.Encoding.Add_Indexed_Frame
     (Encoder,
      (Width => 2, Height => 2, others => <>),
      Giflib.Encoding.Use_Global_Palette,
      (others => <>),
      [0, 1, 1, 0]);
   Require_Success;
   Outcome := Giflib.Encoding.Finish (Encoder);
   Require_Success;

   Ada.Text_IO.Put_Line
     ("encoded GIF bytes:" & Giflib.Destination_Offset'Image (Destination.Offset));
end Encode_Still;
