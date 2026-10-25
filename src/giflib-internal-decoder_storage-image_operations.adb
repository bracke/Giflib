with Giflib.Errors;
with Giflib.Internal.Compositing;
with Giflib.Internal.Disposal;
with Giflib.Internal.Image_Data;
with Giflib.Internal.Pixel_Arithmetic;

package body Giflib.Internal.Decoder_Storage.Image_Operations is
   function Invariant_Failure return Results.Result is
     (Results.Failure (Errors.Make (Errors.Internal_Invariant_Failed)));

   function Decode_Indices
     (Object : in out Resources;
      Source : in out Streams.Source'Class;
      Width : Image_Width;
      Height : Image_Height;
      Interlaced : Boolean;
      Palette : Palettes.Palette;
      Constraints : Limits.Limit_Set;
      Total_Decoded_Pixels : in out Pixel_Count;
      Total_Compressed_Bytes : in out Byte_Count;
      Output : out Streams.Byte_Array;
      Frame : Frame_Ordinal := 0) return Results.Result
   is
   begin
      if not LZW_Allocated (Object) then
         return Invariant_Failure;
      end if;
      return Image_Data.Decode_Indices
        (Object.LZW_Data, Source, Width, Height, Interlaced, Palette,
         Constraints, Total_Decoded_Pixels, Total_Compressed_Bytes,
         Output, Frame);
   end Decode_Indices;

   function Decode_Frame_Scratch
     (Object : in out Resources;
      Source : in out Streams.Source'Class;
      Width : Image_Width;
      Height : Image_Height;
      Interlaced : Boolean;
      Palette : Palettes.Palette;
      Constraints : Limits.Limit_Set;
      Total_Decoded_Pixels : in out Pixel_Count;
      Total_Compressed_Bytes : in out Byte_Count;
      Pixel_Bytes : Byte_Count;
      Frame : Frame_Ordinal := 0) return Results.Result
   is
      Scratch : Owned_Buffers.Byte_Array_Access;
   begin
      if Pixel_Bytes = 0
        or else Pixel_Bytes > Byte_Count (Natural'Last)
        or else Frame_Scratch_Length (Object) < Pixel_Bytes
        or else not LZW_Allocated (Object)
      then
         return Invariant_Failure;
      end if;
      Scratch := Owned_Buffers.Value (Object.Frame_Scratch_Buffer);
      return Image_Data.Decode_Indices
        (Object.LZW_Data, Source, Width, Height, Interlaced, Palette,
         Constraints, Total_Decoded_Pixels, Total_Compressed_Bytes,
         Scratch.all (1 .. Natural (Pixel_Bytes)), Frame);
   end Decode_Frame_Scratch;

   function Initialize_Canvas
     (Object : in out Resources;
      Pixels : Byte_Count;
      Color : Palettes.RGB_Color;
      Alpha : Byte) return Results.Result
   is
      Position : Natural;
   begin
      if Pixels = 0
        or else Pixels > Byte_Count (Natural'Last)
        or else Pixels > Byte_Count'Last / 4
        or else Canvas_Length (Object) < Pixels * 4
      then
         return Invariant_Failure;
      end if;
      for Pixel in 0 .. Natural (Pixels) - 1 loop
         Position := Natural (Pixel_Arithmetic.Component_Offset (Pixel, 4));
         Owned_Buffers.Value (Object.Canvas_Buffer) (1 + Position) := Color.Red;
         Owned_Buffers.Value (Object.Canvas_Buffer) (2 + Position) := Color.Green;
         Owned_Buffers.Value (Object.Canvas_Buffer) (3 + Position) := Color.Blue;
         Owned_Buffers.Value (Object.Canvas_Buffer) (4 + Position) := Alpha;
      end loop;
      return Results.Success;
   end Initialize_Canvas;

   function Fill_Canvas_Rectangle
     (Object : in out Resources;
      Canvas_Width : Image_Width;
      Rectangle : Frames.Rectangle;
      Color : Palettes.RGB_Color;
      Alpha : Byte) return Results.Result
   is
   begin
      if not Canvas_Allocated (Object) then
         return Invariant_Failure;
      end if;
      return Disposal.Fill_Rectangle
        (Owned_Buffers.Value (Object.Canvas_Buffer).all,
         Canvas_Width, Rectangle, Color, Alpha);
   end Fill_Canvas_Rectangle;

   function Capture_Snapshot
     (Object : in out Resources;
      Canvas_Width : Image_Width;
      Rectangle : Frames.Rectangle) return Results.Result
   is
   begin
      if not Canvas_Allocated (Object) or else not Snapshot_Allocated (Object) then
         return Invariant_Failure;
      end if;
      return Disposal.Capture_Rectangle
        (Owned_Buffers.Value (Object.Canvas_Buffer).all,
         Canvas_Width, Rectangle,
         Owned_Buffers.Value (Object.Snapshot_Buffer).all);
   end Capture_Snapshot;

   function Restore_Snapshot
     (Object : in out Resources;
      Canvas_Width : Image_Width;
      Rectangle : Frames.Rectangle) return Results.Result
   is
   begin
      if not Canvas_Allocated (Object) or else not Snapshot_Allocated (Object) then
         return Invariant_Failure;
      end if;
      return Disposal.Restore_Rectangle
        (Owned_Buffers.Value (Object.Canvas_Buffer).all,
         Canvas_Width, Rectangle,
         Owned_Buffers.Value (Object.Snapshot_Buffer).all);
   end Restore_Snapshot;

   function Overlay_Frame_Scratch
     (Object : in out Resources;
      Canvas_Width : Image_Width;
      Rectangle : Frames.Rectangle;
      Pixel_Bytes : Byte_Count;
      Palette : Palettes.Palette;
      Control : Frames.Graphic_Control) return Results.Result
   is
   begin
      if not Canvas_Allocated (Object)
        or else Pixel_Bytes = 0
        or else Pixel_Bytes > Byte_Count (Natural'Last)
        or else Frame_Scratch_Length (Object) < Pixel_Bytes
      then
         return Invariant_Failure;
      end if;
      return Compositing.Overlay
        (Owned_Buffers.Value (Object.Canvas_Buffer).all,
         Canvas_Width, Rectangle,
         Owned_Buffers.Value (Object.Frame_Scratch_Buffer).all
           (1 .. Natural (Pixel_Bytes)),
         Palette, Control);
   end Overlay_Frame_Scratch;

   function Copy_Canvas
     (Object : in out Resources;
      Target : out Streams.Byte_Array) return Results.Result
   is
   begin
      if not Canvas_Allocated (Object) then
         return Invariant_Failure;
      elsif Byte_Count (Target'Length) /= Canvas_Length (Object) then
         return Results.Failure
           (Errors.Make
              (Errors.Buffer_Size_Mismatch,
               (Expected => Canvas_Length (Object),
                Actual => Byte_Count (Target'Length), others => <>)));
      end if;
      Target := Owned_Buffers.Value (Object.Canvas_Buffer).all;
      return Results.Success;
   end Copy_Canvas;
end Giflib.Internal.Decoder_Storage.Image_Operations;
