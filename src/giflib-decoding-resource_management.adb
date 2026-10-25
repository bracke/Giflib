with Giflib.Internal.Disposal;
with Giflib.Internal.Diagnostics;
with Giflib.Internal.Resource_Diagnostics;
with Giflib.Internal.Geometry_Arithmetic;
with Giflib.Internal.LZW;
with Giflib.Internal.Owned_Buffers;
with Giflib.Internal.Pixel_Arithmetic;
with Giflib.Palettes;

package body Giflib.Decoding.Resource_Management is
   use type Internal.Ownership.Allocation_Status;
   package Buffers renames Internal.Owned_Buffers;

   procedure Release (Resources : in out Decoder_Resources) is
   begin
      Internal.Decoder_Storage.Release (Resources);
   end Release;

   procedure Release (Object : in out Decoder) is
   begin
      Release (Object.Resources);
      Object.Has_Pending_Frame := False;
      Object.Has_Previous_Frame := False;
      Object.Previous_Control := Frames.Default_Control;
   end Release;

   function Allocation_Result
     (Object : Decoder;
      Allocation : Internal.Ownership.Allocation_Outcome;
      Include_Frame : Boolean := True)
      return Results.Result
   is
      Context : constant Errors.Diagnostic_Context :=
        Internal.Diagnostics.At_Source
          (Object.Input.all,
           (Frame =>
              (if Include_Frame
               then Errors.Frame_At (Object.Frames_Seen)
               else (Present => False)),
            others => <>));
   begin
      return Results.Failure
        (Internal.Resource_Diagnostics.Allocation_Error
           (Allocation,
            Object.Constraints.Max_Allocation_Bytes,
            Allocation.Attempted,
            Context));
   end Allocation_Result;

   function Ensure_Frame_Scratch
     (Object : in out Decoder;
      Required : Byte_Count) return Results.Result
   is
      Allocation : Internal.Ownership.Allocation_Outcome;
   begin
      if Required > Byte_Count (Natural'Last) then
         return Results.Failure (Errors.Make (Errors.Integer_Overflow));
      end if;
      Allocation := Buffers.Ensure
        (Object.Resources.Frame_Scratch,
         Object.Resources.Allocation_Budget,
         Object.Allocation_Fault,
         Required,
         Object.Constraints.Max_Allocation_Bytes);
      if Allocation.Status /= Internal.Ownership.Allocation_Ready then
         return Allocation_Result (Object, Allocation);
      end if;
      return Results.Success;
   end Ensure_Frame_Scratch;

   function Ensure_LZW_Workspace
     (Object : in out Decoder) return Results.Result
   is
      Allocation : Internal.Ownership.Allocation_Outcome;
   begin
      Allocation := Internal.LZW.Ensure
        (Object.Resources.LZW_Workspace,
         Object.Resources.Allocation_Budget,
         Object.Allocation_Fault,
         Object.Constraints.Max_Allocation_Bytes);
      if Allocation.Status /= Internal.Ownership.Allocation_Ready then
         return Allocation_Result (Object, Allocation);
      end if;
      return Results.Success;
   end Ensure_LZW_Workspace;

   function Setup_Canvas (Object : in out Decoder) return Results.Result is
      Pixels : constant Byte_Count :=
        Internal.Geometry_Arithmetic.Area
          (Object.Header_Data.Width, Object.Header_Data.Height);
      Bytes : constant Byte_Count := Pixels * 4;
      Background : Palettes.RGB_Color := (others => 0);
      Has_Background : Boolean := False;
      Position : Natural;
      Allocation : Internal.Ownership.Allocation_Outcome;
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
      elsif Bytes > Byte_Count (Natural'Last) then
         return Results.Failure
           (Errors.Make
              (Errors.Integer_Overflow,
               Internal.Diagnostics.At_Source (Object.Input.all)));
      end if;
      Allocation := Buffers.Ensure
        (Object.Resources.Canvas,
         Object.Resources.Allocation_Budget,
         Object.Allocation_Fault,
         Bytes,
         Object.Constraints.Max_Allocation_Bytes);
      if Allocation.Status /= Internal.Ownership.Allocation_Ready then
         return Allocation_Result (Object, Allocation, Include_Frame => False);
      end if;
      if Object.Header_Data.Has_Global_Palette
        and then Palettes.Contains
          (Object.Header_Data.Global_Palette, Object.Header_Data.Background_Index)
      then
         Background := Object.Header_Data.Global_Palette.Colors (Object.Header_Data.Background_Index);
         Has_Background := True;
      end if;
      for Pixel in 0 .. Natural (Pixels) - 1 loop
         Position := Natural (Internal.Pixel_Arithmetic.Component_Offset (Pixel, 4));
         Buffers.Value (Object.Resources.Canvas) (1 + Position) := Background.Red;
         Buffers.Value (Object.Resources.Canvas) (2 + Position) := Background.Green;
         Buffers.Value (Object.Resources.Canvas) (3 + Position) := Background.Blue;
         Buffers.Value (Object.Resources.Canvas) (4 + Position) :=
           (if Has_Background then 255 else 0);
      end loop;
      return Results.Success;
   end Setup_Canvas;

   function Fill_Background
     (Object : in out Decoder;
      Rectangle : Frames.Rectangle) return Results.Result
   is
      Color : Palettes.RGB_Color := (others => 0);
      Alpha : Byte := 0;
   begin
      if Object.Header_Data.Has_Global_Palette
        and then Palettes.Contains
          (Object.Header_Data.Global_Palette, Object.Header_Data.Background_Index)
      then
         Color := Object.Header_Data.Global_Palette.Colors (Object.Header_Data.Background_Index);
         Alpha := 255;
      end if;
      return Internal.Disposal.Fill_Rectangle
        (Buffers.Value (Object.Resources.Canvas).all,
         Object.Header_Data.Width,
         Rectangle,
         Color,
         Alpha);
   end Fill_Background;

   function Apply_Previous_Disposal (Object : in out Decoder) return Results.Result is
      Outcome : Results.Result;
   begin
      if not Object.Has_Previous_Frame then
         return Results.Success;
      end if;
      case Object.Previous_Control.Disposal is
         when 2 =>
            Outcome := Fill_Background (Object, Object.Previous_Rectangle);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         when 3 =>
            if not Buffers.Is_Allocated (Object.Resources.Snapshot) then
               return Results.Failure
                 (Errors.Make
                    (Errors.Internal_Invariant_Failed,
                     Internal.Diagnostics.At_Source
                       (Object.Input.all,
                        (Frame => Errors.Frame_At (Object.Frames_Seen),
                         others => <>))));
            end if;
            Outcome := Internal.Disposal.Restore_Rectangle
              (Buffers.Value (Object.Resources.Canvas).all,
               Object.Header_Data.Width,
               Object.Snapshot_Rectangle,
               Buffers.Value (Object.Resources.Snapshot).all);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         when others =>
            null;
      end case;
      Object.Has_Previous_Frame := False;
      return Results.Success;
   end Apply_Previous_Disposal;

   function Save_Snapshot
     (Object : in out Decoder;
      Rectangle : Frames.Rectangle) return Results.Result
   is
      Bytes : constant Byte_Count :=
        Internal.Geometry_Arithmetic.Area (Rectangle.Width, Rectangle.Height) * 4;
      Outcome : Results.Result;
      Allocation : Internal.Ownership.Allocation_Outcome;
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
      elsif Bytes > Byte_Count (Natural'Last) then
         return Results.Failure (Errors.Make (Errors.Integer_Overflow));
      end if;

      Allocation := Buffers.Ensure
        (Object.Resources.Snapshot,
         Object.Resources.Allocation_Budget,
         Object.Allocation_Fault,
         Bytes,
         Object.Constraints.Max_Allocation_Bytes);
      if Allocation.Status /= Internal.Ownership.Allocation_Ready then
         return Allocation_Result (Object, Allocation);
      end if;
      Object.Snapshot_Rectangle := Rectangle;
      Outcome := Internal.Disposal.Capture_Rectangle
        (Buffers.Value (Object.Resources.Canvas).all,
         Object.Header_Data.Width,
         Rectangle,
         Buffers.Value (Object.Resources.Snapshot).all);
      return Outcome;
   end Save_Snapshot;

end Giflib.Decoding.Resource_Management;

