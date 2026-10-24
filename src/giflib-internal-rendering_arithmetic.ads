with Giflib.Frames;

package Giflib.Internal.Rendering_Arithmetic
  with Pure, SPARK_Mode
is
   type Layout_Result is record
      Fits : Boolean := False;
      Pixel_Count : Byte_Count := 0;
      Rectangle_Bytes : Byte_Count := 0;
   end record;

   function Analyze_RGBA
     (Canvas_Length : Natural;
      Canvas_Width  : Image_Width;
      Rectangle     : Frames.Rectangle;
      Extra_Length  : Natural := 0;
      Require_Extra : Boolean := False) return Layout_Result;
end Giflib.Internal.Rendering_Arithmetic;
