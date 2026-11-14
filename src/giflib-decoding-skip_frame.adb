with Giflib.Decoding.Frame_Pipeline;

separate (Giflib.Decoding)
function Skip_Frame (Object : in out Decoder) return Results.Result is
   Ignored_Info : Frame_Info;
   Outcome : Results.Result;
begin
   Outcome := Frame_Pipeline.Start_Skip (Object);
   if not Results.Succeeded (Outcome) then
      return Outcome;
   end if;
   Outcome := Frame_Pipeline.Skip_Data (Object);
   if not Results.Succeeded (Outcome) then
      return Outcome;
   end if;
   return Frame_Pipeline.Finish (Object, Ignored_Info);
end Skip_Frame;
