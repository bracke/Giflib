separate (Giflib.Decoding)
function Skip_Frame (Object : in out Decoder) return Results.Result is
   Ignored_Info : Frame_Info;
   Minimum_Code_Size : Byte;
   Reader : Internal.Blocks.Sub_Block_Reader;
   Outcome : Results.Result;
begin
   if not State_Arithmetic.Can_Process_Frame (Object.Current_State)
   then
      return Invalid_Transition (Object);
   elsif Object.Options.Mode = Composited_RGBA then
      return Results.Failure
        (Errors.Make
           (Errors.Unsupported_Feature,
            Internal.Diagnostics.At_Source
              (Object.Input.all,
               (Frame => Errors.Frame_At (Object.Frames_Seen),
                others => <>))));
   end if;
   if not Object.Has_Pending_Frame then
      return Fail (Object, Errors.Make (Errors.Internal_Invariant_Failed));
   end if;
   State_Arithmetic.Begin_Frame (Object.Current_State);
   Outcome := Internal.Bytes.Read_Byte
     (Object.Input.all, Minimum_Code_Size, Image_Data_Block);
   if not Results.Succeeded (Outcome) then
      return Fail (Object, Outcome.First_Error);
   elsif Minimum_Code_Size < 2 or else Minimum_Code_Size > 8 then
      declare
         Position : constant Streams.Source_Position_Result :=
           Streams.Position (Object.Input.all, 1);
      begin
         return Fail
           (Object,
            Errors.Make
              (Errors.LZW_Invalid_Minimum_Code_Size,
               (Source_Position =>
                  Internal.Diagnostics.With_Source
                    ((others => <>), Position).Source_Position,
                Block => Image_Data_Block,
                Frame => Errors.Frame_At (Object.Frames_Seen),
                Actual => Byte_Count (Minimum_Code_Size),
                others => <>)));
      end;
   end if;
   Internal.Blocks.Initialize
     (Reader,
      Object.Constraints.Max_Compressed_Bytes
        - Object.Total_Compressed_Bytes,
      Compressed_Byte_Limit,
      Image_Data_Block);
   Outcome := Internal.Blocks.Drain (Reader, Object.Input.all);
   Object.Total_Compressed_Bytes :=
     Object.Total_Compressed_Bytes + Internal.Blocks.Total_Bytes (Reader);
   if not Results.Succeeded (Outcome) then
      return Fail (Object, Outcome.First_Error);
   end if;
   return Complete_Frame (Object, Ignored_Info);
end Skip_Frame;
