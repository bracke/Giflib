separate (Giflib.Decoding)
function Decode_Indexed_Frame
  (Object : in out Decoder;
   Target : out Streams.Byte_Array;
   Info : out Frame_Info) return Results.Result
is
   Outcome : Results.Result;
begin
   Outcome := Frame_Pipeline.Start_Decode
     (Object,
      Raw_Indexed,
      Byte_Count (Target'Length),
      Info'Constrained,
      (if Info'Constrained
       then Info.Has_Local_Palette
       else False));
   if not Results.Succeeded (Outcome) then
      return Outcome;
   end if;
   Outcome := Frame_Pipeline.Decode_Indices (Object, Target);
   if not Results.Succeeded (Outcome) then
      return Outcome;
   end if;
   return Complete_Frame (Object, Info);
end Decode_Indexed_Frame;
