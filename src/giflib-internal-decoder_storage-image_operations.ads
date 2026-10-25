with Giflib.Frames;
with Giflib.Limits;
with Giflib.Palettes;
with Giflib.Results;
with Giflib.Streams;

package Giflib.Internal.Decoder_Storage.Image_Operations is
   pragma Preelaborate;

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
      Frame : Frame_Ordinal := 0) return Results.Result;

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
      Frame : Frame_Ordinal := 0) return Results.Result;

   function Initialize_Canvas
     (Object : in out Resources;
      Pixels : Byte_Count;
      Color : Palettes.RGB_Color;
      Alpha : Byte) return Results.Result;

   function Fill_Canvas_Rectangle
     (Object : in out Resources;
      Canvas_Width : Image_Width;
      Rectangle : Frames.Rectangle;
      Color : Palettes.RGB_Color;
      Alpha : Byte) return Results.Result;

   function Capture_Snapshot
     (Object : in out Resources;
      Canvas_Width : Image_Width;
      Rectangle : Frames.Rectangle) return Results.Result;

   function Restore_Snapshot
     (Object : in out Resources;
      Canvas_Width : Image_Width;
      Rectangle : Frames.Rectangle) return Results.Result;

   function Overlay_Frame_Scratch
     (Object : in out Resources;
      Canvas_Width : Image_Width;
      Rectangle : Frames.Rectangle;
      Pixel_Bytes : Byte_Count;
      Palette : Palettes.Palette;
      Control : Frames.Graphic_Control) return Results.Result;

   function Copy_Canvas
     (Object : in out Resources;
      Target : out Streams.Byte_Array) return Results.Result;
end Giflib.Internal.Decoder_Storage.Image_Operations;
