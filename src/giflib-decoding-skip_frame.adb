separate (Giflib.Decoding)
function Skip_Frame (Object : in out Decoder) return Results.Result is
   Ignored_Info : Frame_Info;
   Compressed_Bytes : Byte_Count := Object.Total_Compressed_Bytes;
   Outcome : Results.Result;
begin
   Outcome := Frame_Pipeline.Start_Skip (Object);
   if not Results.Succeeded (Outcome) then
      return Outcome;
   end if;
   Outcome := Internal.Image_Data.Skip
     (Object.Input.all, Object.Constraints, Compressed_Bytes,
      Object.Frames_Seen);
   Session_Transitions.Commit_Resource_Usage
     (Object, Object.Total_Decoded_Pixels, Compressed_Bytes);
   if not Results.Succeeded (Outcome) then
      return Fail (Object, Outcome.First_Error);
   end if;
   return Complete_Frame (Object, Ignored_Info);
end Skip_Frame;
