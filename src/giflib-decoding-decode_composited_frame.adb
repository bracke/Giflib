with Giflib.Decoding.Frame_Pipeline;

separate (Giflib.Decoding)
function Decode_Composited_Frame
  (Object : in out Decoder;
   Target : out Streams.Byte_Array;
   Info : out Frame_Info) return Results.Result
is
   Outcome : Results.Result;
begin
   Outcome := Frame_Pipeline.Start_Decode
     (Object,
      Composited_RGBA,
      Byte_Count (Target'Length),
      Info'Constrained,
      (if Info'Constrained
       then Info.Has_Local_Palette
       else False));
   if not Results.Succeeded (Outcome) then
      return Outcome;
   end if;

   Outcome := Frame_Pipeline.Composite (Object, Target);
   if not Results.Succeeded (Outcome) then
      return Outcome;
   end if;
   return Frame_Pipeline.Finish (Object, Info);
end Decode_Composited_Frame;
