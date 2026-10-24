package Giflib.Internal.Geometry_Arithmetic with SPARK_Mode is
   pragma Pure;

   type Rectangle_Analysis is record
      Pixel_Area : Byte_Count := 0;
      Right_Edge : Byte_Count := 0;
      Bottom_Edge : Byte_Count := 0;
      Bounding_Area : Byte_Count := 0;
      Fits : Boolean := False;
   end record;

   function Area (Width : Image_Width; Height : Image_Height) return Byte_Count
     with Post =>
       Area'Result = Byte_Count (Width) * Byte_Count (Height);

   function Analyze_Rectangle
     (Left : Coordinate;
      Top : Coordinate;
      Width : Image_Width;
      Height : Image_Height;
      Canvas_Width : Image_Width;
      Canvas_Height : Image_Height) return Rectangle_Analysis
     with Post =>
       Analyze_Rectangle'Result.Pixel_Area = Area (Width, Height)
       and then Analyze_Rectangle'Result.Right_Edge =
         Byte_Count (Left) + Byte_Count (Width)
       and then Analyze_Rectangle'Result.Bottom_Edge =
         Byte_Count (Top) + Byte_Count (Height)
       and then Analyze_Rectangle'Result.Bounding_Area =
         Analyze_Rectangle'Result.Right_Edge
           * Analyze_Rectangle'Result.Bottom_Edge
       and then Analyze_Rectangle'Result.Fits =
         (Analyze_Rectangle'Result.Right_Edge <= Byte_Count (Canvas_Width)
          and then Analyze_Rectangle'Result.Bottom_Edge <= Byte_Count (Canvas_Height));
end Giflib.Internal.Geometry_Arithmetic;
