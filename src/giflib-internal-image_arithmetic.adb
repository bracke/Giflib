package body Giflib.Internal.Image_Arithmetic with SPARK_Mode is
   function Required_Extent
     (Width : Image_Width;
      Height : Image_Height;
      Stride : Row_Stride;
      Pixel_Bytes : Pixel_Byte_Count) return Extent_Result
   is
      Row_Bytes : constant Byte_Count :=
        Byte_Count (Width) * Byte_Count (Pixel_Bytes);
      Prior_Rows : Byte_Count;
   begin
      if Byte_Count (Stride) < Row_Bytes then
         return
           (Status => Stride_Too_Short,
            Row_Bytes => Row_Bytes,
            Required_Bytes => 0);
      elsif Height > 1
        and then Byte_Count (Stride) > Byte_Count'Last / Byte_Count (Height - 1)
      then
         return
           (Status => Extent_Overflow,
            Row_Bytes => Row_Bytes,
            Required_Bytes => 0);
      end if;

      Prior_Rows := Byte_Count (Height - 1) * Byte_Count (Stride);
      if Row_Bytes > Byte_Count'Last - Prior_Rows then
         return
           (Status => Extent_Overflow,
            Row_Bytes => Row_Bytes,
            Required_Bytes => 0);
      end if;
      return
        (Status => Extent_OK,
         Row_Bytes => Row_Bytes,
         Required_Bytes => Prior_Rows + Row_Bytes);
   end Required_Extent;
end Giflib.Internal.Image_Arithmetic;
