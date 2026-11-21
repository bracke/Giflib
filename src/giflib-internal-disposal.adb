with Ada.Unchecked_Conversion;
with Interfaces;

with Giflib.Errors;
with Giflib.Internal.Pixel_Arithmetic;
with Giflib.Internal.Rendering_Arithmetic;

package body Giflib.Internal.Disposal is
   Bulk_Row_Threshold : constant := 1_024;
   RGBA_Bytes : constant := 4;
   type RGBA_Pixel is record
      Red : Byte;
      Green : Byte;
      Blue : Byte;
      Alpha : Byte;
   end record
     with Size => 32;
   for RGBA_Pixel use record
      Red at 0 range 0 .. 7;
      Green at 1 range 0 .. 7;
      Blue at 2 range 0 .. 7;
      Alpha at 3 range 0 .. 7;
   end record;
   for RGBA_Pixel'Alignment use 1;
   function To_Word is new Ada.Unchecked_Conversion
     (RGBA_Pixel, Interfaces.Unsigned_32);
   pragma Inline_Always (To_Word);
   type RGBA_Canvas is array (Natural range <>) of Interfaces.Unsigned_32
     with Component_Size => 32;

   function Fill_Rectangle
     (Canvas       : in out Streams.Byte_Array;
      Canvas_Width : Image_Width;
      Rectangle    : Frames.Rectangle;
      Color        : Palettes.RGB_Color;
      Alpha        : Byte)
      return Results.Result
   is
      Position : Natural;
      Remaining : Natural;
   begin
      if not Rendering_Arithmetic.Analyze_RGBA
        (Canvas'Length, Canvas_Width, Rectangle).Fits
      then
         return Results.Failure
           (Errors.Make (Errors.Internal_Invariant_Failed));
      end if;
      declare
         Packed_Color : constant Interfaces.Unsigned_32 :=
           To_Word
             ((Red => Color.Red,
               Green => Color.Green,
               Blue => Color.Blue,
               Alpha => Alpha));
         Canvas_Pixels : RGBA_Canvas
           (0 .. Canvas'Length / RGBA_Bytes - 1)
           with Import, Address => Canvas'Address, Alignment => 1;
         --  Analyze_RGBA validates every destination pixel before this loop.
         --  Treating the byte buffer as packed RGBA avoids four repeated
         --  stores and their checks for each already-validated pixel.
         pragma Suppress (Index_Check);
         pragma Suppress (Overflow_Check);
      begin
         for Row in 0 .. Natural (Rectangle.Height) - 1 loop
            Position := Natural
              (Pixel_Arithmetic.Pixel_Index
                 (Natural (Rectangle.Left), Natural (Rectangle.Top) + Row,
                  Canvas_Width));
            Remaining := Natural (Rectangle.Width);
            while Remaining > 0 loop
               Canvas_Pixels (Position) := Packed_Color;
               Position := Position + 1;
               Remaining := Remaining - 1;
            end loop;
         end loop;
      end;
      return Results.Success;
   end Fill_Rectangle;

   function Capture_Rectangle
     (Canvas       : Streams.Byte_Array;
      Canvas_Width : Image_Width;
      Rectangle    : Frames.Rectangle;
      Snapshot     : in out Streams.Byte_Array)
      return Results.Result
   is
      Canvas_Position : Natural;
      Snapshot_Position : Natural := 0;
      Row_Bytes : constant Positive := Natural (Rectangle.Width) * 4;
   begin
      if not Rendering_Arithmetic.Analyze_RGBA
        (Canvas'Length,
         Canvas_Width,
         Rectangle,
         Snapshot'Length,
         Require_Extra => True).Fits
      then
         return Results.Failure
           (Errors.Make (Errors.Internal_Invariant_Failed));
      end if;
      for Row in 0 .. Natural (Rectangle.Height) - 1 loop
         Canvas_Position := Natural
           (Pixel_Arithmetic.Byte_Offset
              (Natural (Rectangle.Left), Natural (Rectangle.Top) + Row,
               Canvas_Width, 4));
         if Row_Bytes >= Bulk_Row_Threshold then
            Snapshot
              (Snapshot'First + Snapshot_Position
                 .. Snapshot'First + Snapshot_Position + Row_Bytes - 1) :=
                Canvas
                  (Canvas'First + Canvas_Position
                     .. Canvas'First + Canvas_Position + Row_Bytes - 1);
         else
            for Offset in 0 .. Row_Bytes - 1 loop
               Snapshot (Snapshot'First + Snapshot_Position + Offset) :=
                 Canvas (Canvas'First + Canvas_Position + Offset);
            end loop;
         end if;
         Snapshot_Position := Snapshot_Position + Row_Bytes;
      end loop;
      return Results.Success;
   end Capture_Rectangle;

   function Restore_Rectangle
     (Canvas       : in out Streams.Byte_Array;
      Canvas_Width : Image_Width;
      Rectangle    : Frames.Rectangle;
      Snapshot     : Streams.Byte_Array)
      return Results.Result
   is
      Canvas_Position : Natural;
      Snapshot_Position : Natural := 0;
      Row_Bytes : constant Positive := Natural (Rectangle.Width) * 4;
   begin
      if not Rendering_Arithmetic.Analyze_RGBA
        (Canvas'Length,
         Canvas_Width,
         Rectangle,
         Snapshot'Length,
         Require_Extra => True).Fits
      then
         return Results.Failure
           (Errors.Make (Errors.Internal_Invariant_Failed));
      end if;
      for Row in 0 .. Natural (Rectangle.Height) - 1 loop
         Canvas_Position := Natural
           (Pixel_Arithmetic.Byte_Offset
              (Natural (Rectangle.Left), Natural (Rectangle.Top) + Row,
               Canvas_Width, 4));
         if Row_Bytes >= Bulk_Row_Threshold then
            Canvas
              (Canvas'First + Canvas_Position
                 .. Canvas'First + Canvas_Position + Row_Bytes - 1) :=
                Snapshot
                  (Snapshot'First + Snapshot_Position
                     .. Snapshot'First + Snapshot_Position + Row_Bytes - 1);
         else
            for Offset in 0 .. Row_Bytes - 1 loop
               Canvas (Canvas'First + Canvas_Position + Offset) :=
                 Snapshot (Snapshot'First + Snapshot_Position + Offset);
            end loop;
         end if;
         Snapshot_Position := Snapshot_Position + Row_Bytes;
      end loop;
      return Results.Success;
   end Restore_Rectangle;
end Giflib.Internal.Disposal;
