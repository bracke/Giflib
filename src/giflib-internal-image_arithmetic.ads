package Giflib.Internal.Image_Arithmetic with SPARK_Mode is
   pragma Pure;

   subtype Pixel_Byte_Count is Positive range 1 .. 4;
   type Extent_Status is (Extent_OK, Stride_Too_Short, Extent_Overflow);

   type Extent_Result is record
      Status : Extent_Status := Extent_OK;
      Row_Bytes : Byte_Count := 0;
      Required_Bytes : Byte_Count := 0;
   end record;

   function Required_Extent
     (Width : Image_Width;
      Height : Image_Height;
      Stride : Row_Stride;
      Pixel_Bytes : Pixel_Byte_Count) return Extent_Result
     with Post =>
       Required_Extent'Result.Row_Bytes
         = Byte_Count (Width) * Byte_Count (Pixel_Bytes)
       and then
         (if Required_Extent'Result.Status = Extent_OK then
             Required_Extent'Result.Required_Bytes
               = Byte_Count (Height - 1) * Byte_Count (Stride)
                 + Required_Extent'Result.Row_Bytes
          else
             Required_Extent'Result.Required_Bytes = 0);
end Giflib.Internal.Image_Arithmetic;
