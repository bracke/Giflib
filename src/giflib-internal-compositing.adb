with Ada.Unchecked_Conversion;
with Interfaces;

with Giflib.Errors;
with Giflib.Internal.Pixel_Arithmetic;
with Giflib.Internal.Rendering_Arithmetic;

package body Giflib.Internal.Compositing is
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
   type Packed_Palette is array (Palette_Index) of Interfaces.Unsigned_32;

   function Overlay
     (Canvas       : in out Streams.Byte_Array;
      Canvas_Width : Image_Width;
      Rectangle    : Frames.Rectangle;
      Indices      : Streams.Byte_Array;
      Palette      : Palettes.Palette;
      Control      : Frames.Graphic_Control;
      Indices_Validated : Boolean := False)
      return Results.Result
   is
      Layout : constant Rendering_Arithmetic.Layout_Result :=
        Rendering_Arithmetic.Analyze_RGBA
          (Canvas'Length, Canvas_Width, Rectangle);
      Packed_Colors : Packed_Palette := [others => 0];

      generic
         Check_Indices : Boolean;
         Use_Transparency : Boolean;
      function Render return Results.Result;

      function Render return Results.Result is
         Canvas_Position : Natural;
         Index_Position : Natural;
         Index : Palette_Index;
         Remaining : Natural;
         Canvas_Pixels : RGBA_Canvas
           (0 .. Canvas'Length / RGBA_Bytes - 1)
           with Import, Address => Canvas'Address, Alignment => 1;
         --  Overlay validates the complete source and destination spans before
         --  selecting this loop.  Keeping the checks here would repeat four
         --  destination checks for every already-validated pixel.
         pragma Suppress (Index_Check);
         pragma Suppress (Overflow_Check);
      begin
         for Row in 0 .. Natural (Rectangle.Height) - 1 loop
            Index_Position := Natural
              (Pixel_Arithmetic.Pixel_Index (0, Row, Rectangle.Width));
            Canvas_Position := Natural
              (Pixel_Arithmetic.Pixel_Index
                 (Natural (Rectangle.Left), Natural (Rectangle.Top) + Row,
                  Canvas_Width));
            Remaining := Natural (Rectangle.Width);
            while Remaining > 0 loop
               Index := Palette_Index
                 (Indices (Indices'First + Index_Position));
               if Check_Indices and then not Palettes.Contains (Palette, Index)
               then
                  return Results.Failure
                    (Errors.Make (Errors.Internal_Invariant_Failed));
               end if;
               if not Use_Transparency
                 or else Index /= Control.Transparent_Index
               then
                  Canvas_Pixels (Canvas_Position) :=
                    Packed_Colors (Index);
               end if;
               Index_Position := Index_Position + 1;
               Canvas_Position := Canvas_Position + 1;
               Remaining := Remaining - 1;
            end loop;
         end loop;
         return Results.Success;
      end Render;

      function Render_Checked_Opaque is new Render (True, False);
      function Render_Checked_Transparent is new Render (True, True);
      function Render_Validated_Opaque is new Render (False, False);
      function Render_Validated_Transparent is new Render (False, True);
   begin
      if not Layout.Fits
        or else Canvas'Length < RGBA_Bytes
        or else Canvas'Length mod RGBA_Bytes /= 0
        or else Byte_Count (Indices'Length) /= Layout.Pixel_Count
        or else Palette.Length = 0
        or else
          (Control.Has_Transparency
           and then not Palettes.Contains
             (Palette, Control.Transparent_Index))
      then
         return Results.Failure
           (Errors.Make (Errors.Internal_Invariant_Failed));
      end if;
      for Index in Palette_Index
        range 0 .. Palette_Index (Palette.Length - 1)
      loop
         Packed_Colors (Index) :=
           To_Word
             ((Red => Palette.Colors (Index).Red,
               Green => Palette.Colors (Index).Green,
               Blue => Palette.Colors (Index).Blue,
               Alpha => 255));
      end loop;
      if Indices_Validated then
         return
           (if Control.Has_Transparency
            then Render_Validated_Transparent
            else Render_Validated_Opaque);
      end if;
      return
        (if Control.Has_Transparency
         then Render_Checked_Transparent
         else Render_Checked_Opaque);
   end Overlay;
end Giflib.Internal.Compositing;
