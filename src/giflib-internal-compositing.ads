with Giflib.Frames;
with Giflib.Palettes;
with Giflib.Results;
with Giflib.Streams;

package Giflib.Internal.Compositing is
   pragma Preelaborate;

   function Overlay
     (Canvas       : in out Streams.Byte_Array;
      Canvas_Width : Image_Width;
      Rectangle    : Frames.Rectangle;
      Indices      : Streams.Byte_Array;
      Palette      : Palettes.Palette;
      Control      : Frames.Graphic_Control) return Results.Result;
end Giflib.Internal.Compositing;
