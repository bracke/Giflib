with Giflib.Frames;
with Giflib.Palettes;
with Giflib.Results;
with Giflib.Streams;

package Giflib.Internal.Disposal is
   pragma Preelaborate;

   function Fill_Rectangle
     (Canvas       : in out Streams.Byte_Array;
      Canvas_Width : Image_Width;
      Rectangle    : Frames.Rectangle;
      Color        : Palettes.RGB_Color;
      Alpha        : Byte) return Results.Result;

   function Capture_Rectangle
     (Canvas       : Streams.Byte_Array;
      Canvas_Width : Image_Width;
      Rectangle    : Frames.Rectangle;
      Snapshot     : in out Streams.Byte_Array) return Results.Result;

   function Restore_Rectangle
     (Canvas       : in out Streams.Byte_Array;
      Canvas_Width : Image_Width;
      Rectangle    : Frames.Rectangle;
      Snapshot     : Streams.Byte_Array) return Results.Result;
end Giflib.Internal.Disposal;
