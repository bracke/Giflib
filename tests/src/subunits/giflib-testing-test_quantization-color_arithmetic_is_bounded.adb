separate (Giflib.Testing.Test_Quantization)
procedure Color_Arithmetic_Is_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   package Arithmetic renames Giflib.Internal.Quantization_Arithmetic;
   White_Cell : constant Arithmetic.Histogram_Index :=
     Arithmetic.Histogram_Of ((255, 255, 255));
begin
   Assert (Arithmetic.Histogram_Of ((0, 0, 0)) = 0 and then White_Cell = 32_767,
           "color histogram endpoint is wrong");
   Assert (Arithmetic.Red_Bucket (White_Cell) = 31
           and then Arithmetic.Green_Bucket (White_Cell) = 31
           and then Arithmetic.Blue_Bucket (White_Cell) = 31,
           "histogram color decomposition is wrong");
   Assert (Arithmetic.Clamp (Long_Integer'First) = 0
           and then Arithmetic.Clamp (128) = 128
           and then Arithmetic.Clamp (Long_Integer'Last) = 255,
           "quantization channel clamping is wrong");
   Assert (Arithmetic.Squared_Distance ((0, 0, 0), (255, 255, 255)) = 195_075
           and then Arithmetic.Squared_Distance ((7, 8, 9), (7, 8, 9)) = 0,
           "quantization color distance is wrong");
end Color_Arithmetic_Is_Bounded;

