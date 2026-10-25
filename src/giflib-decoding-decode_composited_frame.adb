separate (Giflib.Decoding)
function Decode_Composited_Frame
  (Object : in out Decoder;
   Target : out Streams.Byte_Array;
   Info : out Frame_Info) return Results.Result
is
   Prepared : Prepared_Frame renames Object.Pending_Frame;
   Rectangle : Frames.Rectangle;
   Pixel_Bytes : Byte_Count;
   Outcome : Results.Result;
begin
   if not State_Arithmetic.Can_Process_Frame (Object.Current_State)
   then
      return Invalid_Transition (Object);
   elsif Object.Options.Mode /= Composited_RGBA then
      return Results.Failure
        (Errors.Make
           (Errors.Unsupported_Feature,
            Internal.Diagnostics.At_Source
              (Object.Input.all,
               (Frame => Errors.Frame_At (Object.Frames_Seen),
                others => <>))));
   elsif not Internal.Decoder_Storage.Canvas_Allocated (Object.Resources)
   then
      return Fail (Object, Errors.Make (Errors.Internal_Invariant_Failed));
   elsif not Object.Has_Pending_Frame then
      return Fail (Object, Errors.Make (Errors.Internal_Invariant_Failed));
   end if;
   Outcome := Validate_Frame_Output
     (Object,
      Byte_Count (Target'Length),
      Internal.Decoder_Storage.Canvas_Length (Object.Resources),
      Info'Constrained,
      (if Info'Constrained
       then Info.Has_Local_Palette
       else Prepared.Has_Local_Palette));
   if not Results.Succeeded (Outcome) then
      return Outcome;
   end if;

   Outcome := Resource_Management.Apply_Previous_Disposal (Object);
   if not Results.Succeeded (Outcome) then
      return Fail (Object, Outcome.First_Error);
   end if;
   State_Arithmetic.Begin_Frame (Object);
   if Prepared.Control.Disposal > 3
     and then Object.Options.Strictness = Strict
   then
      return Fail
        (Object,
         Errors.Make
           (Errors.Reserved_Disposal_Method,
            Internal.Diagnostics.At_Source
              (Object.Input.all,
               (Block => Graphic_Control_Extension_Block,
                Frame => Errors.Frame_At (Object.Frames_Seen),
                Actual => Byte_Count (Prepared.Control.Disposal),
                others => <>))));
   elsif Prepared.Control.Disposal > 3 then
      Add_Warning
        (Object,
         Errors.Reserved_Value_Accepted,
         Errors.Compatibility,
         Internal.Diagnostics.At_Source
           (Object.Input.all,
            (Block => Graphic_Control_Extension_Block,
             Frame => Errors.Frame_At (Object.Frames_Seen),
             Actual => Byte_Count (Prepared.Control.Disposal),
             others => <>)));
   end if;
   Rectangle :=
     (Left => Prepared.Left,
      Top => Prepared.Top,
      Width => Prepared.Width,
      Height => Prepared.Height);
   if Prepared.Control.Disposal = 3 then
      Outcome := Resource_Management.Save_Snapshot (Object, Rectangle);
      if not Results.Succeeded (Outcome) then
         return Fail (Object, Outcome.First_Error);
      end if;
   end if;

   Pixel_Bytes := Internal.Geometry_Arithmetic.Area
     (Prepared.Width, Prepared.Height);
   Outcome := Resource_Management.Ensure_Frame_Scratch (Object, Pixel_Bytes);
   if not Results.Succeeded (Outcome) then
      return Fail (Object, Outcome.First_Error);
   end if;
   Outcome := Resource_Management.Ensure_LZW_Workspace (Object);
   if not Results.Succeeded (Outcome) then
      return Fail (Object, Outcome.First_Error);
   end if;
   Outcome := Internal.Decoder_Storage.Image_Operations.Decode_Frame_Scratch
     (Object.Resources,
      Object.Input.all,
      Prepared.Width,
      Prepared.Height,
      Prepared.Interlaced,
      Prepared.Palette,
      Object.Constraints,
      Object.Total_Decoded_Pixels, Object.Total_Compressed_Bytes,
      Pixel_Bytes,
      Object.Frames_Seen);
   if not Results.Succeeded (Outcome) then
      return Fail (Object, Outcome.First_Error);
   end if;

   Outcome := Internal.Decoder_Storage.Image_Operations.Overlay_Frame_Scratch
     (Object.Resources, Object.Header_Data.Width, Rectangle, Pixel_Bytes,
      Prepared.Palette, Prepared.Control);
   if not Results.Succeeded (Outcome) then
      return Fail (Object, Outcome.First_Error);
   end if;
   Outcome := Internal.Decoder_Storage.Image_Operations.Copy_Canvas
     (Object.Resources, Target);
   if not Results.Succeeded (Outcome) then
      return Fail (Object, Outcome.First_Error);
   end if;
   Object.Previous_Rectangle := Rectangle;
   Object.Previous_Control := Prepared.Control;
   Object.Has_Previous_Frame := True;
   return Complete_Frame (Object, Info);
end Decode_Composited_Frame;
