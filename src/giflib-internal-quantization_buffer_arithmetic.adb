package body Giflib.Internal.Quantization_Buffer_Arithmetic
  with SPARK_Mode
is
   function Span_Of (Width : Image_Width) return Error_Span is
     (Natural (Width) + 2);

   function Error_Buffer_Length (Width : Image_Width) return Positive is
     (6 * Span_Of (Width));

   function Allocation_Bytes
     (Width : Image_Width;
      Element_Bytes : Positive) return Byte_Count
   is
     (Byte_Count (Error_Buffer_Length (Width)) * Byte_Count (Element_Bytes));

   function Error_Index
     (Group : Group_Index;
      Channel : Channel_Index;
      Offset : Natural;
      Span : Error_Span) return Natural
   is (Group * 3 * Span + Channel * Span + Offset);
end Giflib.Internal.Quantization_Buffer_Arithmetic;
