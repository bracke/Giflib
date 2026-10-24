separate (Giflib.Decoding)
function Decode_Composited_Frame
  (Object : in out Decoder;
   Target : out Streams.Byte_Array;
   Info : out Frame_Info) return Results.Result
is
   Prepared : Prepared_Frame;
   Rectangle : Frames.Rectangle;
   Pixel_Bytes : Byte_Count;
   Outcome : Results.Result;
begin
   Info := (others => <>);
   if not State_Arithmetic.Can_Process_Frame (Object.Current_State)
   then
      return Invalid_Transition (Object);
   elsif Object.Options.Mode /= Composited_RGBA then
      return Results.Failure
        (Errors.Make
           (Errors.Unsupported_Feature,
            (Has_Source => Input_Position (Object).Available,
             Source => Input_Position (Object).Value,
             Has_Frame => True,
             Frame => Object.Frames_Seen,
             others => <>)));
   elsif not Internal.Owned_Buffers.Is_Allocated (Object.Resources.Canvas) then
      return Fail (Object, Errors.Make (Errors.Internal_Invariant_Failed));
   elsif Byte_Count (Target'Length) /=
     Internal.Owned_Buffers.Length (Object.Resources.Canvas)
   then
      return Results.Failure
        (Errors.Make
           (Errors.LZW_Output_Size_Mismatch,
            (Has_Source => Input_Position (Object).Available,
             Source => Input_Position (Object).Value,
             Has_Frame => True, Frame => Object.Frames_Seen,
             Expected => Internal.Owned_Buffers.Length (Object.Resources.Canvas),
             Actual => Byte_Count (Target'Length),
             others => <>)));
   end if;

   Outcome := Resource_Management.Apply_Previous_Disposal (Object);
   if not Results.Succeeded (Outcome) then
      return Fail (Object, Outcome.First_Error);
   end if;
   Outcome := Prepare_Frame (Object, Prepared);
   if not Results.Succeeded (Outcome) then
      return Fail (Object, Outcome.First_Error);
   end if;
   if Prepared.Control.Disposal > 3
     and then Object.Options.Strictness = Strict
   then
      return Fail
        (Object,
         Errors.Make
           (Errors.Reserved_Disposal_Method,
            (Has_Source => Input_Position (Object).Available,
             Source => Input_Position (Object).Value,
             Block => Graphic_Control_Extension_Block,
             Has_Frame => True, Frame => Object.Frames_Seen,
             Actual => Byte_Count (Prepared.Control.Disposal),
             others => <>)));
   elsif Prepared.Control.Disposal > 3 then
      Add_Warning
        (Object,
         Errors.Reserved_Value_Accepted,
         Errors.Compatibility,
         (Has_Source => Input_Position (Object).Available,
          Source => Input_Position (Object).Value,
          Block => Graphic_Control_Extension_Block,
          Has_Frame => True, Frame => Object.Frames_Seen,
          Actual => Byte_Count (Prepared.Control.Disposal),
          others => <>));
   end if;
   Rectangle :=
     (Left => Prepared.Descriptor.Left,
      Top => Prepared.Descriptor.Top,
      Width => Prepared.Descriptor.Width,
      Height => Prepared.Descriptor.Height);
   if Prepared.Control.Disposal = 3 then
      Outcome := Resource_Management.Save_Snapshot (Object, Rectangle);
      if not Results.Succeeded (Outcome) then
         return Fail (Object, Outcome.First_Error);
      end if;
   end if;

   Pixel_Bytes := Internal.Geometry_Arithmetic.Area
     (Prepared.Descriptor.Width, Prepared.Descriptor.Height);
   Outcome := Resource_Management.Ensure_Frame_Scratch (Object, Pixel_Bytes);
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
      Object.Total_Decoded_Pixels, Object.Total_Compressed_Bytes,
      Internal.Owned_Buffers.Value (Object.Resources.Frame_Scratch).all
        (1 .. Natural (Pixel_Bytes)),
      Object.Frames_Seen);
   if not Results.Succeeded (Outcome) then
      return Fail (Object, Outcome.First_Error);
   end if;

   Outcome := Internal.Compositing.Overlay
     (Internal.Owned_Buffers.Value (Object.Resources.Canvas).all,
      Object.Header_Data.Width,
      Rectangle,
      Internal.Owned_Buffers.Value (Object.Resources.Frame_Scratch).all
        (1 .. Natural (Pixel_Bytes)),
      Prepared.Palette,
      Prepared.Control);
   if not Results.Succeeded (Outcome) then
      return Fail (Object, Outcome.First_Error);
   end if;
   Target := Internal.Owned_Buffers.Value (Object.Resources.Canvas).all;
   Object.Previous_Rectangle := Rectangle;
   Object.Previous_Control := Prepared.Control;
   Object.Has_Previous_Frame := True;
   Complete_Frame (Object, Prepared, Info);
   return Results.Success;
end Decode_Composited_Frame;
