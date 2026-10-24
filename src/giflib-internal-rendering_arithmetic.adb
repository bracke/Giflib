package body Giflib.Internal.Rendering_Arithmetic
  with SPARK_Mode
is
   function Analyze_RGBA
     (Canvas_Length : Natural;
      Canvas_Width  : Image_Width;
      Rectangle     : Frames.Rectangle;
      Extra_Length  : Natural := 0;
      Require_Extra : Boolean := False) return Layout_Result
   is
      Pixels : constant Byte_Count :=
        Byte_Count (Rectangle.Width) * Byte_Count (Rectangle.Height);
      Rectangle_Bytes : constant Byte_Count := Pixels * 4;
      Required_Canvas : constant Byte_Count :=
        (Byte_Count (Rectangle.Top) + Byte_Count (Rectangle.Height))
          * Byte_Count (Canvas_Width) * 4;
      Fits : constant Boolean :=
        Byte_Count (Rectangle.Left) + Byte_Count (Rectangle.Width)
          <= Byte_Count (Canvas_Width)
        and then Required_Canvas <= Byte_Count (Canvas_Length)
        and then
          (not Require_Extra
           or else Rectangle_Bytes <= Byte_Count (Extra_Length));
   begin
      return
        (Fits => Fits,
         Pixel_Count => Pixels,
         Rectangle_Bytes => Rectangle_Bytes);
   end Analyze_RGBA;
end Giflib.Internal.Rendering_Arithmetic;
