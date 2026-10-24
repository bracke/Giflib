package body Giflib.Internal.Geometry_Arithmetic with SPARK_Mode is
   function Area (Width : Image_Width; Height : Image_Height) return Byte_Count is
   begin
      return Byte_Count (Width) * Byte_Count (Height);
   end Area;

   function Analyze_Rectangle
     (Left : Coordinate;
      Top : Coordinate;
      Width : Image_Width;
      Height : Image_Height;
      Canvas_Width : Image_Width;
      Canvas_Height : Image_Height) return Rectangle_Analysis
   is
      Right_Edge : constant Byte_Count := Byte_Count (Left) + Byte_Count (Width);
      Bottom_Edge : constant Byte_Count := Byte_Count (Top) + Byte_Count (Height);
   begin
      return
        (Pixel_Area => Area (Width, Height),
         Right_Edge => Right_Edge,
         Bottom_Edge => Bottom_Edge,
         Bounding_Area => Right_Edge * Bottom_Edge,
         Fits => Right_Edge <= Byte_Count (Canvas_Width)
           and then Bottom_Edge <= Byte_Count (Canvas_Height));
   end Analyze_Rectangle;
end Giflib.Internal.Geometry_Arithmetic;
