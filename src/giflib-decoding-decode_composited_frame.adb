separate (Giflib.Decoding)
function Decode_Composited_Frame
  (Object : in out Decoder;
   Target : out Streams.Byte_Array;
   Info : out Frame_Info) return Results.Result
is
   Rectangle : Frames.Rectangle;
   Pixel_Bytes : Byte_Count;
   Outcome : Results.Result;
begin
   Outcome := Frame_Pipeline.Start_Decode
     (Object,
      Composited_RGBA,
      Byte_Count (Target'Length),
      Info'Constrained,
      (if Info'Constrained
       then Info.Has_Local_Palette
       else False));
   if not Results.Succeeded (Outcome) then
      return Outcome;
   end if;

   Outcome := Resource_Management.Apply_Previous_Disposal (Object);
   if not Results.Succeeded (Outcome) then
      return Fail (Object, Outcome.First_Error);
   end if;
   if Object.Pending_Frame.Control.Disposal > 3
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
                Actual => Byte_Count (Object.Pending_Frame.Control.Disposal),
                others => <>))));
   elsif Object.Pending_Frame.Control.Disposal > 3 then
      Add_Warning
        (Object,
         Errors.Reserved_Value_Accepted,
         Errors.Compatibility,
         Internal.Diagnostics.At_Source
           (Object.Input.all,
            (Block => Graphic_Control_Extension_Block,
             Frame => Errors.Frame_At (Object.Frames_Seen),
             Actual => Byte_Count (Object.Pending_Frame.Control.Disposal),
             others => <>)));
   end if;
   Rectangle :=
     (Left => Object.Pending_Frame.Left,
      Top => Object.Pending_Frame.Top,
      Width => Object.Pending_Frame.Width,
      Height => Object.Pending_Frame.Height);
   if Object.Pending_Frame.Control.Disposal = 3 then
      Outcome := Resource_Management.Save_Snapshot (Object, Rectangle);
      if not Results.Succeeded (Outcome) then
         return Fail (Object, Outcome.First_Error);
      end if;
   end if;

   Pixel_Bytes := Internal.Geometry_Arithmetic.Area
     (Object.Pending_Frame.Width, Object.Pending_Frame.Height);
   Outcome := Resource_Management.Ensure_Frame_Scratch (Object, Pixel_Bytes);
   if not Results.Succeeded (Outcome) then
      return Fail (Object, Outcome.First_Error);
   end if;
   Outcome := Frame_Pipeline.Decode_Scratch (Object, Pixel_Bytes);
   if not Results.Succeeded (Outcome) then
      return Outcome;
   end if;

   Outcome := Internal.Decoder_Storage.Image_Operations.Overlay_Frame_Scratch
     (Object.Resources, Object.Header_Data.Width, Rectangle, Pixel_Bytes,
      Object.Pending_Frame.Palette, Object.Pending_Frame.Control);
   if not Results.Succeeded (Outcome) then
      return Fail (Object, Outcome.First_Error);
   end if;
   Outcome := Internal.Decoder_Storage.Image_Operations.Copy_Canvas
     (Object.Resources, Target);
   if not Results.Succeeded (Outcome) then
      return Fail (Object, Outcome.First_Error);
   end if;
   Session_Transitions.Commit_Composited_Frame
     (Object, Rectangle, Object.Pending_Frame.Control);
   return Complete_Frame (Object, Info);
end Decode_Composited_Frame;
