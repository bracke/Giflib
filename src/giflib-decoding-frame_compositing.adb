with Giflib.Decoding.Failure_Handling;
with Giflib.Decoding.Frame_Data;
with Giflib.Decoding.Resource_Management;
with Giflib.Decoding.Session_Transitions;
with Giflib.Internal.Decoder_Storage.Image_Operations;
with Giflib.Internal.Diagnostics;
with Giflib.Internal.Geometry_Arithmetic;

package body Giflib.Decoding.Frame_Compositing is
   use type Frames.Disposal_Method;

   type Background_Definition is record
      Color : Palettes.RGB_Color := (others => 0);
      Alpha : Byte := 0;
   end record;

   function Background_Of
     (Header : Header_Info) return Background_Definition is
   begin
      if Header.Has_Global_Palette
        and then Palettes.Contains
          (Header.Global_Palette, Header.Background_Index)
      then
         return
           (Color => Header.Global_Palette.Colors (Header.Background_Index),
            Alpha => 255);
      end if;
      return (others => <>);
   end Background_Of;

   function Setup_Canvas
     (Object : in out Decoder;
      Header : Header_Info) return Results.Result
   is
      Pixels : constant Byte_Count :=
        Internal.Geometry_Arithmetic.Area (Header.Width, Header.Height);
      Bytes : constant Byte_Count := Pixels * 4;
      Background : constant Background_Definition := Background_Of (Header);
      Outcome : Results.Result;
   begin
      if Pixels > Byte_Count (Object.Constraints.Max_Canvas_Pixels) then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               Internal.Diagnostics.At_Source
                 (Object.Input.all,
                  (Expected => Byte_Count (Object.Constraints.Max_Canvas_Pixels),
                   Actual => Pixels,
                   Limit => Canvas_Pixel_Limit,
                   others => <>))));
      elsif Bytes > Object.Constraints.Max_Canvas_Bytes then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               Internal.Diagnostics.At_Source
                 (Object.Input.all,
                  (Expected => Object.Constraints.Max_Canvas_Bytes,
                   Actual => Bytes,
                   Limit => Canvas_Byte_Limit,
                   others => <>))));
      end if;
      Outcome := Resource_Management.Ensure_Canvas (Object, Bytes);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      return Internal.Decoder_Storage.Image_Operations.Initialize_Canvas
        (Object.Resources, Pixels, Background.Color, Background.Alpha);
   end Setup_Canvas;

   function Fill_Background
     (Object : in out Decoder;
      Rectangle : Frames.Rectangle) return Results.Result
   is
      Background : constant Background_Definition :=
        Background_Of (Object.Header_Data);
   begin
      return Internal.Decoder_Storage.Image_Operations.Fill_Canvas_Rectangle
        (Object.Resources, Object.Header_Data.Width, Rectangle,
         Background.Color, Background.Alpha);
   end Fill_Background;

   function Apply_Previous_Disposal
     (Object : in out Decoder) return Results.Result
   is
      Outcome : Results.Result;
   begin
      if not Object.Previous_Frame.Present then
         return Results.Success;
      end if;
      case Object.Previous_Frame.Control.Disposal is
         when 2 =>
            Outcome := Fill_Background
              (Object, Object.Previous_Frame.Rectangle);
         when 3 =>
            if not Internal.Decoder_Storage.Snapshot_Allocated
              (Object.Resources)
            then
               return Results.Failure
                 (Errors.Make
                    (Errors.Internal_Invariant_Failed,
                     Internal.Diagnostics.At_Source
                       (Object.Input.all,
                        (Frame => Errors.Frame_At (Object.Frames_Seen),
                         others => <>))));
            end if;
            Outcome :=
              Internal.Decoder_Storage.Image_Operations.Restore_Snapshot
                (Object.Resources, Object.Header_Data.Width,
                 Object.Previous_Frame.Snapshot_Rectangle);
         when others =>
            Outcome := Results.Success;
      end case;
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      Session_Transitions.Clear_Previous_Frame (Object);
      return Results.Success;
   end Apply_Previous_Disposal;

   function Save_Snapshot
     (Object : in out Decoder;
      Rectangle : Frames.Rectangle) return Results.Result
   is
      Bytes : constant Byte_Count :=
        Internal.Geometry_Arithmetic.Area
          (Rectangle.Width, Rectangle.Height) * 4;
      Outcome : Results.Result;
   begin
      if Bytes > Object.Constraints.Max_Compositor_Snapshot_Bytes then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               Internal.Diagnostics.At_Source
                 (Object.Input.all,
                  (Frame => Errors.Frame_At (Object.Frames_Seen),
                   Expected => Object.Constraints.Max_Compositor_Snapshot_Bytes,
                   Actual => Bytes,
                   Limit => Snapshot_Byte_Limit,
                   others => <>))));
      end if;
      Outcome := Resource_Management.Ensure_Snapshot (Object, Bytes);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      return Internal.Decoder_Storage.Image_Operations.Capture_Snapshot
        (Object.Resources, Object.Header_Data.Width, Rectangle);
   end Save_Snapshot;

   function Composite
     (Object : in out Decoder;
      Target : out Streams.Byte_Array) return Results.Result
   is
      Rectangle : Frames.Rectangle;
      Pixel_Bytes : Byte_Count;
      Decoded_Pixels : Pixel_Count := Object.Total_Decoded_Pixels;
      Compressed_Bytes : Byte_Count := Object.Total_Compressed_Bytes;
      Outcome : Results.Result;
   begin
      Outcome := Apply_Previous_Disposal (Object);
      if not Results.Succeeded (Outcome) then
         return Failure_Handling.Fail (Object, Outcome.First_Error);
      end if;
      if Object.Pending_Frame.Control.Disposal > 3
        and then Object.Options.Strictness = Strict
      then
         return Failure_Handling.Fail
           (Object,
            Errors.Make
              (Errors.Reserved_Disposal_Method,
               Internal.Diagnostics.At_Source
                 (Object.Input.all,
                  (Block => Graphic_Control_Extension_Block,
                   Frame => Errors.Frame_At (Object.Frames_Seen),
                   Actual => Byte_Count
                     (Object.Pending_Frame.Control.Disposal),
                   others => <>))));
      elsif Object.Pending_Frame.Control.Disposal > 3 then
         Failure_Handling.Record_Warning
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
         Outcome := Save_Snapshot (Object, Rectangle);
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

      Outcome :=
        Internal.Decoder_Storage.Image_Operations.Overlay_Frame_Scratch
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
