with Giflib.Errors;
with Giflib.Internal.Pixel_Arithmetic;
with Giflib.Internal.Rendering_Arithmetic;

package body Giflib.Internal.Disposal is
   function Fill_Rectangle
     (Canvas       : in out Streams.Byte_Array;
      Canvas_Width : Image_Width;
      Rectangle    : Frames.Rectangle;
      Color        : Palettes.RGB_Color;
      Alpha        : Byte)
      return Results.Result
   is
      Position : Natural;
   begin
      if not Rendering_Arithmetic.Analyze_RGBA
        (Canvas'Length, Canvas_Width, Rectangle).Fits
      then
         return Results.Failure
           (Errors.Make (Errors.Internal_Invariant_Failed));
      end if;
      for Row in 0 .. Natural (Rectangle.Height) - 1 loop
         for Column in 0 .. Natural (Rectangle.Width) - 1 loop
            Position := Natural
              (Pixel_Arithmetic.Byte_Offset
                 (Natural (Rectangle.Left) + Column,
                  Natural (Rectangle.Top) + Row,
                  Canvas_Width,
                  4));
            Canvas (Canvas'First + Position) := Color.Red;
            Canvas (Canvas'First + Position + 1) := Color.Green;
            Canvas (Canvas'First + Position + 2) := Color.Blue;
            Canvas (Canvas'First + Position + 3) := Alpha;
         end loop;
      end loop;
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
         for Column in 0 .. Natural (Rectangle.Width) - 1 loop
            Canvas_Position := Natural
              (Pixel_Arithmetic.Byte_Offset
                 (Natural (Rectangle.Left) + Column,
                  Natural (Rectangle.Top) + Row,
                  Canvas_Width,
                  4));
            for Component in 0 .. 3 loop
               Snapshot (Snapshot'First + Snapshot_Position + Component) :=
                 Canvas (Canvas'First + Canvas_Position + Component);
            end loop;
            Snapshot_Position := Snapshot_Position + 4;
         end loop;
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
         for Column in 0 .. Natural (Rectangle.Width) - 1 loop
            Canvas_Position := Natural
              (Pixel_Arithmetic.Byte_Offset
                 (Natural (Rectangle.Left) + Column,
                  Natural (Rectangle.Top) + Row,
                  Canvas_Width,
                  4));
            for Component in 0 .. 3 loop
               Canvas (Canvas'First + Canvas_Position + Component) :=
                 Snapshot (Snapshot'First + Snapshot_Position + Component);
            end loop;
            Snapshot_Position := Snapshot_Position + 4;
         end loop;
      end loop;
      return Results.Success;
   end Restore_Rectangle;
end Giflib.Internal.Disposal;
