package Giflib.Internal.Quantization_Buffer_Arithmetic
  with Pure, SPARK_Mode
is
   subtype Error_Span is Natural range 3 .. 65_537;
   subtype Group_Index is Natural range 0 .. 1;
   subtype Channel_Index is Natural range 0 .. 2;

   function Span_Of (Width : Image_Width) return Error_Span
     with Post => Span_Of'Result = Natural (Width) + 2;

   function Error_Buffer_Length (Width : Image_Width) return Positive
     with Post =>
       Error_Buffer_Length'Result = 6 * Span_Of (Width);

   function Allocation_Bytes
     (Width : Image_Width;
      Element_Bytes : Positive) return Byte_Count
     with Pre =>
            Byte_Count (Element_Bytes) <=
              Byte_Count'Last / Byte_Count (Error_Buffer_Length (Width)),
          Post =>
            Allocation_Bytes'Result =
              Byte_Count (Error_Buffer_Length (Width))
              * Byte_Count (Element_Bytes);

   function Error_Index
     (Group : Group_Index;
      Channel : Channel_Index;
      Offset : Natural;
      Span : Error_Span) return Natural
     with Pre => Offset < Span,
          Post =>
            Error_Index'Result =
              Group * 3 * Span + Channel * Span + Offset
            and then Error_Index'Result < 6 * Span;
end Giflib.Internal.Quantization_Buffer_Arithmetic;
