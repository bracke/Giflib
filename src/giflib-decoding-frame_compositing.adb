with Giflib.Decoding.Canvas_Policy;
with Giflib.Decoding.Disposal_Policy;
with Giflib.Decoding.Failure_Handling;
with Giflib.Decoding.Frame_Data;
with Giflib.Decoding.Resource_Management;
with Giflib.Decoding.Session_Transitions;
with Giflib.Internal.Decoder_Storage.Image_Operations;
with Giflib.Internal.Diagnostics;
with Giflib.Internal.Geometry_Arithmetic;

package body Giflib.Decoding.Frame_Compositing is
   use type Frames.Disposal_Method;

   function Setup_Canvas
     (Object : in out Decoder; Header : Header_Info) return Results.Result is
     (Canvas_Policy.Setup_Canvas (Object, Header));

   function Composite
     (Object : in out Decoder; Target : out Streams.Byte_Array)
      return Results.Result
   is
      Rectangle : Frames.Rectangle;
      Pixel_Bytes : Byte_Count;
      Decoded_Pixels : Pixel_Count := Object.Total_Decoded_Pixels;
      Compressed_Bytes : Byte_Count := Object.Total_Compressed_Bytes;
      Outcome : Results.Result;
   begin
      Outcome := Disposal_Policy.Apply_Previous (Object);
      if not Results.Succeeded (Outcome) then
         return Failure_Handling.Fail (Object, Outcome.First_Error);
      end if;
      if Object.Pending_Frame.Control.Disposal > 3
        and then Object.Options.Strictness = Strict
      then
         return Failure_Handling.Fail
           (Object, Errors.Make (Errors.Reserved_Disposal_Method,
            Internal.Diagnostics.At_Source
              (Object.Input.all,
               (Block => Graphic_Control_Extension_Block,
                Frame => Errors.Frame_At (Object.Frames_Seen),
                Actual => Byte_Count (Object.Pending_Frame.Control.Disposal),
                others => <>))));
      elsif Object.Pending_Frame.Control.Disposal > 3 then
         Failure_Handling.Record_Warning
           (Object, Errors.Reserved_Value_Accepted, Errors.Compatibility,
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
         Outcome := Disposal_Policy.Save_Snapshot (Object, Rectangle);
         if not Results.Succeeded (Outcome) then
            return Failure_Handling.Fail (Object, Outcome.First_Error);
         end if;
      end if;
      Pixel_Bytes := Internal.Geometry_Arithmetic.Area
        (Object.Pending_Frame.Width, Object.Pending_Frame.Height);
      Outcome := Resource_Management.Ensure_Frame_Scratch
        (Object, Pixel_Bytes);
      if not Results.Succeeded (Outcome) then
         return Failure_Handling.Fail (Object, Outcome.First_Error);
      end if;
      Outcome := Frame_Data.Decode_Scratch
        (Object, Pixel_Bytes, Decoded_Pixels, Compressed_Bytes);
      Session_Transitions.Commit_Resource_Usage
        (Object, Decoded_Pixels, Compressed_Bytes);
      if not Results.Succeeded (Outcome) then
         return Failure_Handling.Fail (Object, Outcome.First_Error);
      end if;
      Outcome := Internal.Decoder_Storage.Image_Operations.Overlay_Frame_Scratch
        (Object.Resources, Object.Header_Data.Width, Rectangle, Pixel_Bytes,
         Object.Pending_Frame.Palette, Object.Pending_Frame.Control);
      if not Results.Succeeded (Outcome) then
         return Failure_Handling.Fail (Object, Outcome.First_Error);
      end if;
      Outcome := Internal.Decoder_Storage.Image_Operations.Copy_Canvas
        (Object.Resources, Target);
      if not Results.Succeeded (Outcome) then
         return Failure_Handling.Fail (Object, Outcome.First_Error);
      end if;
      Session_Transitions.Commit_Composited_Frame
        (Object, Rectangle, Object.Pending_Frame.Control);
      return Results.Success;
   end Composite;
end Giflib.Decoding.Frame_Compositing;
