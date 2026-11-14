separate (Giflib.Testing.Test_Compositing)
procedure Pixel_Offsets_Are_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   package Arithmetic renames Giflib.Internal.Pixel_Arithmetic;
begin
   Assert (Arithmetic.Pixel_Index (2, 3, 10) = 32,
           "row-major pixel index is wrong");
   Assert (Arithmetic.Byte_Offset (2, 3, 10, 4) = 128,
           "RGBA byte offset is wrong");
   Assert (Arithmetic.Component_Offset (65_535, 4) = 262_140,
           "component offset is wrong");
end Pixel_Offsets_Are_Bounded;
