separate (Giflib.Decoding)
function Skip_Frame (Object : in out Decoder) return Results.Result is
   Prepared : Prepared_Frame;
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
               (Has_Source => Position.Available,
                Source => Position.Value,
                Block => Image_Data_Block,
                Has_Frame => True,
                Frame => Object.Frames_Seen,
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
   Complete_Frame (Object, Prepared, Ignored_Info);
   return Results.Success;
end Skip_Frame;
