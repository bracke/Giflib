package Giflib.Internal.Pixel_Arithmetic with SPARK_Mode is
   pragma Pure;

   subtype Component_Count is Positive range 1 .. 4;

   function Pixel_Index
     (X : Natural;
      Y : Natural;
      Row_Width : Image_Width) return Byte_Count
     with Post =>
       Pixel_Index'Result =
         Byte_Count (Y) * Byte_Count (Row_Width) + Byte_Count (X);

   function Byte_Offset
     (X : Natural;
      Y : Natural;
      Row_Width : Image_Width;
      Components : Component_Count) return Byte_Count
     with Post =>
       Byte_Offset'Result =
         Pixel_Index (X, Y, Row_Width) * Byte_Count (Components);

   function Component_Offset
     (Ordinal : Natural;
      Components : Component_Count) return Byte_Count
     with Post =>
       Component_Offset'Result = Byte_Count (Ordinal) * Byte_Count (Components);
end Giflib.Internal.Pixel_Arithmetic;
