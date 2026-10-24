package body Giflib.Internal.Pixel_Arithmetic with SPARK_Mode is
   function Pixel_Index
     (X : Natural;
      Y : Natural;
      Row_Width : Image_Width) return Byte_Count
   is
   begin
      return Byte_Count (Y) * Byte_Count (Row_Width) + Byte_Count (X);
   end Pixel_Index;

   function Byte_Offset
     (X : Natural;
      Y : Natural;
      Row_Width : Image_Width;
      Components : Component_Count) return Byte_Count
   is
   begin
      return Pixel_Index (X, Y, Row_Width) * Byte_Count (Components);
   end Byte_Offset;

   function Component_Offset
     (Ordinal : Natural;
      Components : Component_Count) return Byte_Count
   is
   begin
      return Byte_Count (Ordinal) * Byte_Count (Components);
   end Component_Offset;
end Giflib.Internal.Pixel_Arithmetic;
