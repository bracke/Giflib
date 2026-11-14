with Giflib.Decoding.Failure_Handling;
with Giflib.Decoding.Output_Validation;
with Giflib.Decoding.Resource_Management;
with Giflib.Decoding.Session_Transitions;
with Giflib.Decoding.State_Arithmetic;
with Giflib.Internal.Container;
with Giflib.Internal.Decoder_Storage;
with Giflib.Internal.Diagnostics;
with Giflib.Internal.Geometry_Arithmetic;

package body Giflib.Decoding.Frame_Lifecycle is
   function Prepare (Object : in out Decoder) return Results.Result
   is
      Prepared : Prepared_Frame := (Present => True, others => <>);
      Descriptor : Internal.Container.Image_Descriptor;
      Outcome : Results.Result;
   begin
      Outcome := Internal.Container.Read_Image_Descriptor
        (Object.Input.all,
         Object.Header_Data,
         Object.Constraints,
         Descriptor,
         Prepared.Palette,
         Strictness => Object.Options.Strictness,
         Separator_Already_Read => True);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      Prepared.Left := Descriptor.Left;
      Prepared.Top := Descriptor.Top;
      Prepared.Width := Descriptor.Width;
      Prepared.Height := Descriptor.Height;
      Prepared.Has_Local_Palette := Descriptor.Has_Local_Palette;
      Prepared.Interlaced := Descriptor.Interlaced;
      Prepared.Local_Palette_Sorted := Descriptor.Local_Palette_Sorted;
      if Descriptor.Reserved_Bits /= 0 then
         Failure_Handling.Record_Warning
           (Object,
            Errors.Reserved_Value_Accepted,
            Errors.Compatibility,
            (Source_Position => Descriptor.Packed_Field_Position,
             Block => Image_Descriptor_Block,
             Frame => Errors.Frame_At (Object.Frames_Seen),
             Expected => 0,
             Actual => Byte_Count (Descriptor.Reserved_Bits),
             others => <>));
      end if;
      Prepared.Control :=
        (if Object.Pending_Control.Present
         then Object.Pending_Control.Value
         else Frames.Default_Control);
      if Prepared.Control.Has_Transparency
        and then not Palettes.Contains
          (Prepared.Palette, Prepared.Control.Transparent_Index)
      then
         return Results.Failure
           (Errors.Make
              (Errors.Palette_Index_Out_Of_Range,
               Internal.Diagnostics.At_Source
                 (Object.Input.all,
                  (Block => Graphic_Control_Extension_Block,
                   Frame => Errors.Frame_At (Object.Frames_Seen),
                   Expected => Byte_Count (Prepared.Palette.Length - 1),
                   Actual => Byte_Count (Prepared.Control.Transparent_Index),
                   others => <>))));
      end if;
      Session_Transitions.Stage_Frame (Object, Prepared);
      return Results.Success;
   end Prepare;

   function Finish
     (Object : in out Decoder;
      Info : out Frame_Info) return Results.Result
   is
      Produced : constant Frame_Info :=
        (if Object.Pending_Frame.Has_Local_Palette
         then
           (Has_Local_Palette => True,
            Ordinal => Object.Frames_Seen,
            Left => Object.Pending_Frame.Left,
            Top => Object.Pending_Frame.Top,
            Width => Object.Pending_Frame.Width,
            Height => Object.Pending_Frame.Height,
            Interlaced => Object.Pending_Frame.Interlaced,
            Effective_Palette => Object.Pending_Frame.Palette,
            Control => Object.Pending_Frame.Control,
            Local_Palette_Sorted =>
              Object.Pending_Frame.Local_Palette_Sorted)
         else
           (Has_Local_Palette => False,
            Ordinal => Object.Frames_Seen,
            Left => Object.Pending_Frame.Left,
            Top => Object.Pending_Frame.Top,
            Width => Object.Pending_Frame.Width,
            Height => Object.Pending_Frame.Height,
            Interlaced => Object.Pending_Frame.Interlaced,
            Effective_Palette => Object.Pending_Frame.Palette,
            Control => Object.Pending_Frame.Control));
   begin
      Info := Produced;
      Session_Transitions.Complete_Frame (Object);
      return Results.Success;
   end Finish;

   function Start_Decode
     (Object : in out Decoder;
      Required_Mode : Output_Mode;
      Target_Length : Byte_Count;
      Info_Is_Constrained : Boolean;
      Info_Has_Local_Palette : Boolean) return Results.Result
   is
      Expected_Length : Byte_Count;
      Outcome : Results.Result;
   begin
      if not State_Arithmetic.Can_Process_Frame (Object.Current_State) then
         return Failure_Handling.Invalid_State (Object);
      elsif Object.Options.Mode /= Required_Mode then
         return Results.Failure
           (Errors.Make
              (Errors.Unsupported_Feature,
               Internal.Diagnostics.At_Source
                 (Object.Input.all,
                  (Frame => Errors.Frame_At (Object.Frames_Seen),
                   others => <>))));
      elsif not Object.Pending_Frame.Present then
         return Failure_Handling.Fail
           (Object, Errors.Make (Errors.Internal_Invariant_Failed));
      end if;
      case Required_Mode is
         when Raw_Indexed =>
            Expected_Length := Internal.Geometry_Arithmetic.Area
              (Object.Pending_Frame.Width, Object.Pending_Frame.Height);
         when Expanded_Frame =>
            Expected_Length := Internal.Geometry_Arithmetic.Area
              (Object.Pending_Frame.Width, Object.Pending_Frame.Height) * 4;
         when Composited_RGBA =>
            if not Internal.Decoder_Storage.Canvas_Allocated
              (Object.Resources)
            then
               return Failure_Handling.Fail
                 (Object, Errors.Make (Errors.Internal_Invariant_Failed));
            end if;
            Expected_Length :=
              Internal.Decoder_Storage.Canvas_Length (Object.Resources);
      end case;
      Outcome := Output_Validation.Validate
        (Object, Target_Length, Expected_Length,
         Info_Is_Constrained,
         (if Info_Is_Constrained
          then Info_Has_Local_Palette
          else Object.Pending_Frame.Has_Local_Palette));
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      Session_Transitions.Begin_Frame (Object);
      Outcome := Resource_Management.Ensure_LZW_Workspace (Object);
      return
        (if Results.Succeeded (Outcome)
         then Results.Success
         else Failure_Handling.Fail (Object, Outcome.First_Error));
   end Start_Decode;

   function Start_Skip (Object : in out Decoder) return Results.Result is
   begin
      if not State_Arithmetic.Can_Process_Frame (Object.Current_State) then
         return Failure_Handling.Invalid_State (Object);
      elsif Object.Options.Mode = Composited_RGBA then
         return Results.Failure
           (Errors.Make
              (Errors.Unsupported_Feature,
               Internal.Diagnostics.At_Source
                 (Object.Input.all,
                  (Frame => Errors.Frame_At (Object.Frames_Seen),
                   others => <>))));
      elsif not Object.Pending_Frame.Present then
         return Failure_Handling.Fail
           (Object, Errors.Make (Errors.Internal_Invariant_Failed));
      end if;
      Session_Transitions.Begin_Frame (Object);
      return Results.Success;
   end Start_Skip;
end Giflib.Decoding.Frame_Lifecycle;
