separate (Giflib.Decoding)
function Decode_Expanded_Frame
  (Object : in out Decoder;
   Target : out Streams.Byte_Array;
   Info : out Frame_Info) return Results.Result
is
   Prepared : Prepared_Frame renames Object.Pending_Frame;
   Pixels : Byte_Count;
   Outcome : Results.Result;
   Source_Position, Target_Position : Natural;
   Index : Palette_Index;
   Color : Palettes.RGB_Color;
begin
   if not State_Arithmetic.Can_Process_Frame (Object.Current_State)
   then
      return Invalid_Transition (Object);
   elsif Object.Options.Mode /= Expanded_Frame then
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
   Pixels := Internal.Geometry_Arithmetic.Area
     (Prepared.Width, Prepared.Height);
   Outcome := Validate_Frame_Output
     (Object,
      Byte_Count (Target'Length),
      Pixels * 4,
      Info'Constrained,
      (if Info'Constrained
       then Info.Has_Local_Palette
       else Prepared.Has_Local_Palette));
   if not Results.Succeeded (Outcome) then
      return Outcome;
   end if;
   State_Arithmetic.Begin_Frame (Object.Current_State);
   Outcome := Resource_Management.Ensure_LZW_Workspace (Object);
   if not Results.Succeeded (Outcome) then
      return Fail (Object, Outcome.First_Error);
   end if;
   Outcome := Internal.Decoder_Storage.Image_Operations.Decode_Indices
     (Object.Resources,
      Object.Input.all,
      Prepared.Width,
      Prepared.Height,
      Prepared.Interlaced,
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
   return Complete_Frame (Object, Info);
end Decode_Expanded_Frame;
