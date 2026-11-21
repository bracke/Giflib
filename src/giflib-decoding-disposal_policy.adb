with Giflib.Decoding.Canvas_Policy;
with Giflib.Decoding.Resource_Management;
with Giflib.Decoding.Session_Transitions;
with Giflib.Internal.Decoder_Storage.Image_Operations;
with Giflib.Internal.Diagnostics;
with Giflib.Internal.Geometry_Arithmetic;

package body Giflib.Decoding.Disposal_Policy is
   function Apply_Previous (Object : in out Decoder) return Results.Result is
      Outcome : Results.Result;
   begin
      if not Object.Previous_Frame.Present then return Results.Success; end if;
      case Object.Previous_Frame.Control.Disposal is
         when 2 =>
            Outcome := Canvas_Policy.Fill_Background
              (Object, Object.Previous_Frame.Rectangle);
         when 3 =>
            if not Internal.Decoder_Storage.Snapshot_Allocated
              (Object.Resources)
            then
               return Results.Failure
                 (Errors.Make (Errors.Internal_Invariant_Failed,
                  Internal.Diagnostics.At_Source
                    (Object.Input.all,
                     (Frame => Errors.Frame_At (Object.Frames_Seen),
                      others => <>))));
            end if;
            Outcome := Internal.Decoder_Storage.Image_Operations.Restore_Snapshot
              (Object.Resources, Object.Header_Data.Width,
               Object.Previous_Frame.Snapshot_Rectangle);
         when others => Outcome := Results.Success;
      end case;
      if not Results.Succeeded (Outcome) then return Outcome; end if;
      Session_Transitions.Clear_Previous_Frame (Object);
      return Results.Success;
   end Apply_Previous;

   function Save_Snapshot
     (Object : in out Decoder; Rectangle : Frames.Rectangle)
      return Results.Result
   is
      Bytes : constant Byte_Count := Internal.Geometry_Arithmetic.Area
        (Rectangle.Width, Rectangle.Height) * 4;
      Outcome : Results.Result;
   begin
      if Bytes > Object.Constraints.Max_Compositor_Snapshot_Bytes then
         return Results.Failure
           (Errors.Make (Errors.Limit_Exceeded,
            Internal.Diagnostics.At_Source
              (Object.Input.all,
               (Frame => Errors.Frame_At (Object.Frames_Seen),
                Expected => Object.Constraints.Max_Compositor_Snapshot_Bytes,
                Actual => Bytes, Limit => Snapshot_Byte_Limit, others => <>))));
      end if;
      Outcome := Resource_Management.Ensure_Snapshot (Object, Bytes);
      if not Results.Succeeded (Outcome) then return Outcome; end if;
      return Internal.Decoder_Storage.Image_Operations.Capture_Snapshot
        (Object.Resources, Object.Header_Data.Width, Rectangle);
   end Save_Snapshot;
end Giflib.Decoding.Disposal_Policy;
