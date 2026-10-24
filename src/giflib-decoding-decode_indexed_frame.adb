separate (Giflib.Decoding)
function Decode_Indexed_Frame
  (Object : in out Decoder;
   Target : out Streams.Byte_Array;
   Info : out Frame_Info) return Results.Result
is
   Prepared : Prepared_Frame;
   Outcome : Results.Result;
begin
   Info := (others => <>);
   if not State_Arithmetic.Can_Process_Frame (Object.Current_State)
   then
      return Invalid_Transition (Object);
   elsif Object.Options.Mode /= Raw_Indexed then
      return Results.Failure
        (Errors.Make
           (Errors.Unsupported_Feature,
            (Has_Source => Input_Position (Object).Available,
             Source => Input_Position (Object).Value,
             Has_Frame => True,
             Frame => Object.Frames_Seen,
             others => <>)));
   end if;
   Outcome := Prepare_Frame (Object, Prepared);
   if not Results.Succeeded (Outcome) then
      return Fail (Object, Outcome.First_Error);
   end if;
   Outcome := Resource_Management.Ensure_LZW_Workspace (Object);
   if not Results.Succeeded (Outcome) then
      return Fail (Object, Outcome.First_Error);
   end if;
   Outcome := Internal.Image_Data.Decode_Indices
     (Object.Resources.LZW_Workspace,
      Object.Input.all,
      Prepared.Descriptor,
      Prepared.Palette,
      Object.Constraints,
      Object.Total_Decoded_Pixels,
      Object.Total_Compressed_Bytes,
      Target,
      Object.Frames_Seen);
   if not Results.Succeeded (Outcome) then
      return Fail (Object, Outcome.First_Error);
   end if;
   Complete_Frame (Object, Prepared, Info);
   return Results.Success;
end Decode_Indexed_Frame;
