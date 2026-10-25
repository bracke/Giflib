separate (Giflib.Decoding)
function Decode_Expanded_Frame
  (Object : in out Decoder;
   Target : out Streams.Byte_Array;
   Info : out Frame_Info) return Results.Result
is
   Pixels : Byte_Count;
   Outcome : Results.Result;
   Source_Position, Target_Position : Natural;
   Index : Palette_Index;
   Color : Palettes.RGB_Color;
begin
   Outcome := Frame_Pipeline.Start_Decode
     (Object,
      Expanded_Frame,
      Byte_Count (Target'Length),
      Info'Constrained,
      (if Info'Constrained
       then Info.Has_Local_Palette
       else False));
   if not Results.Succeeded (Outcome) then
      return Outcome;
   end if;
   Pixels := Internal.Geometry_Arithmetic.Area
     (Object.Pending_Frame.Width, Object.Pending_Frame.Height);
   Outcome := Frame_Pipeline.Decode_Indices
     (Object, Target (Target'First .. Target'First + Natural (Pixels) - 1));
   if not Results.Succeeded (Outcome) then
      return Outcome;
   end if;
   for Pixel in reverse 0 .. Natural (Pixels) - 1 loop
      Source_Position := Target'First + Pixel;
      Target_Position := Target'First
        + Natural (Internal.Pixel_Arithmetic.Component_Offset (Pixel, 4));
      Index := Palette_Index (Target (Source_Position));
      Color := Object.Pending_Frame.Palette.Colors (Index);
      Target (Target_Position) := Color.Red;
      Target (Target_Position + 1) := Color.Green;
      Target (Target_Position + 2) := Color.Blue;
      Target (Target_Position + 3) :=
        (if Object.Pending_Frame.Control.Has_Transparency
             and then Index = Object.Pending_Frame.Control.Transparent_Index
         then 0
         else 255);
   end loop;
   return Complete_Frame (Object, Info);
end Decode_Expanded_Frame;
