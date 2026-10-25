separate (Giflib.Encoding)
function Add_Indexed_Frame
  (Object : in out Encoder;
   Info : Frame_Info;
   Palette : Frame_Palette;
   Pixels : Streams.Byte_Array) return Results.Result
is
begin
   return Frame_Pipeline.Add_Indexed (Object, Info, Palette, Pixels);
end Add_Indexed_Frame;
