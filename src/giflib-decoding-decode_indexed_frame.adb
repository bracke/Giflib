separate (Giflib.Decoding)
function Decode_Indexed_Frame
  (Object : in out Decoder;
   Target : out Streams.Byte_Array;
   Info : out Frame_Info) return Results.Result
is
   Prepared : Prepared_Frame renames Object.Pending_Frame;
   Outcome : Results.Result;
begin
   if not State_Arithmetic.Can_Process_Frame (Object.Current_State)
   then
      return Invalid_Transition (Object);
   elsif Object.Options.Mode /= Raw_Indexed then
      return Results.Failure
        (Errors.Make
           (Errors.Unsupported_Feature,
            Internal.Diagnostics.At_Source
              (Object.Input.all,
               (Frame => Errors.Frame_At (Object.Frames_Seen),
                others => <>))));
   elsif not Object.Has_Pending_Frame then
      return Fail (Object, Errors.Make (Errors.Internal_Invariant_Failed));
   end if;
   Outcome := Validate_Frame_Output
     (Object,
      Byte_Count (Target'Length),
      Internal.Geometry_Arithmetic.Area (Prepared.Width, Prepared.Height),
      Info'Constrained,
      (if Info'Constrained
       then Info.Has_Local_Palette
       else Prepared.Has_Local_Palette));
   if not Results.Succeeded (Outcome) then
      return Outcome;
   end if;
   State_Arithmetic.Transition (Object.Current_State, Decoding_Frame);
   Outcome := Resource_Management.Ensure_LZW_Workspace (Object);
   if not Results.Succeeded (Outcome) then
      return Fail (Object, Outcome.First_Error);
   end if;
   Outcome := Internal.Image_Data.Decode_Indices
     (Object.Resources.LZW_Workspace,
      Object.Input.all,
      Prepared.Width,
      Prepared.Height,
      Prepared.Interlaced,
      Prepared.Palette,
      Object.Constraints,
      Object.Total_Decoded_Pixels,
      Object.Total_Compressed_Bytes,
      Target,
      Object.Frames_Seen);
   if not Results.Succeeded (Outcome) then
      return Fail (Object, Outcome.First_Error);
   end if;
   return Complete_Frame (Object, Info);
end Decode_Indexed_Frame;
