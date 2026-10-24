separate (Giflib.Decoding)
function Decode_Expanded_Frame
  (Object : in out Decoder;
   Target : out Streams.Byte_Array;
   Info : out Frame_Info) return Results.Result
is
   Prepared : Prepared_Frame;
   Pixels : Byte_Count;
   Outcome : Results.Result;
   Source_Position, Target_Position : Natural;
   Index : Palette_Index;
   Color : Palettes.RGB_Color;
begin
   Info := (others => <>);
   if not State_Arithmetic.Can_Process_Frame (Object.Current_State)
   then
      return Invalid_Transition (Object);
   elsif Object.Options.Mode /= Expanded_Frame then
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
   Pixels := Internal.Geometry_Arithmetic.Area
     (Prepared.Descriptor.Width, Prepared.Descriptor.Height);
   if Byte_Count (Target'Length) /= Pixels * 4 then
      return Fail
        (Object,
         Errors.Make
           (Errors.LZW_Output_Size_Mismatch,
            (Has_Source => Input_Position (Object).Available,
             Source => Input_Position (Object).Value,
             Has_Frame => True, Frame => Object.Frames_Seen,
             Expected => Pixels * 4,
             Actual => Byte_Count (Target'Length), others => <>)));
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
      Target (Target'First .. Target'First + Natural (Pixels) - 1),
      Object.Frames_Seen);
   if not Results.Succeeded (Outcome) then
      return Fail (Object, Outcome.First_Error);
   end if;
   for Pixel in reverse 0 .. Natural (Pixels) - 1 loop
      Source_Position := Target'First + Pixel;
      Target_Position := Target'First
        + Natural (Internal.Pixel_Arithmetic.Component_Offset (Pixel, 4));
      Index := Palette_Index (Target (Source_Position));
      Color := Prepared.Palette.Colors (Index);
      Target (Target_Position) := Color.Red;
      Target (Target_Position + 1) := Color.Green;
      Target (Target_Position + 2) := Color.Blue;
      Target (Target_Position + 3) :=
        (if Prepared.Control.Has_Transparency
             and then Index = Prepared.Control.Transparent_Index
         then 0
         else 255);
   end loop;
   Complete_Frame (Object, Prepared, Info);
   return Results.Success;
end Decode_Expanded_Frame;
