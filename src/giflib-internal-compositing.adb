with Giflib.Errors;
with Giflib.Internal.Pixel_Arithmetic;
with Giflib.Internal.Rendering_Arithmetic;

package body Giflib.Internal.Compositing is
   function Overlay
     (Canvas       : in out Streams.Byte_Array;
      Canvas_Width : Image_Width;
      Rectangle    : Frames.Rectangle;
      Indices      : Streams.Byte_Array;
      Palette      : Palettes.Palette;
      Control      : Frames.Graphic_Control)
      return Results.Result
   is
      Canvas_Position : Natural;
      Index_Position : Natural;
      Index : Palette_Index;
      Color : Palettes.RGB_Color;
      Layout : constant Rendering_Arithmetic.Layout_Result :=
        Rendering_Arithmetic.Analyze_RGBA
          (Canvas'Length, Canvas_Width, Rectangle);
   begin
      if not Layout.Fits
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
      for Value of Indices loop
         if not Palettes.Contains (Palette, Palette_Index (Value)) then
            return Results.Failure
              (Errors.Make (Errors.Internal_Invariant_Failed));
         end if;
      end loop;
      for Row in 0 .. Natural (Rectangle.Height) - 1 loop
         for Column in 0 .. Natural (Rectangle.Width) - 1 loop
            Index_Position := Natural
              (Pixel_Arithmetic.Pixel_Index
                 (Column, Row, Rectangle.Width));
            Index := Palette_Index
              (Indices (Indices'First + Index_Position));
            if not Control.Has_Transparency
              or else Index /= Control.Transparent_Index
            then
               Color := Palette.Colors (Index);
               Canvas_Position := Natural
                 (Pixel_Arithmetic.Byte_Offset
                    (Natural (Rectangle.Left) + Column,
                     Natural (Rectangle.Top) + Row,
                     Canvas_Width,
                     4));
               Canvas (Canvas'First + Canvas_Position) := Color.Red;
               Canvas (Canvas'First + Canvas_Position + 1) := Color.Green;
               Canvas (Canvas'First + Canvas_Position + 2) := Color.Blue;
               Canvas (Canvas'First + Canvas_Position + 3) := 255;
            end if;
         end loop;
      end loop;
      return Results.Success;
   end Overlay;
end Giflib.Internal.Compositing;
