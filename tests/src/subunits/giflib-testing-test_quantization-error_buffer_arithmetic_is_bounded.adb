separate (Giflib.Testing.Test_Quantization)
procedure Error_Buffer_Arithmetic_Is_Bounded
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   package Arithmetic renames Giflib.Internal.Quantization_Buffer_Arithmetic;
   Span : constant Arithmetic.Error_Span := Arithmetic.Span_Of (65_535);
   Last : constant Natural :=
     Arithmetic.Error_Index (1, 2, Natural (Span) - 1, Span);
begin
   Assert (Span = 65_537, "maximum dither span is wrong");
   Assert
     (Arithmetic.Error_Buffer_Length (65_535) = 393_222
      and then Last = 393_221,
      "maximum dither buffer index is wrong");
   Assert
     (Arithmetic.Allocation_Bytes (65_535, Long_Integer'Size / 8)
        = Giflib.Byte_Count (393_222 * (Long_Integer'Size / 8)),
      "dither allocation size is wrong");
end Error_Buffer_Arithmetic_Is_Bounded;

