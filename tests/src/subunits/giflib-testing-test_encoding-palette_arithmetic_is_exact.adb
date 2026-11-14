separate (Giflib.Testing.Test_Encoding)
procedure Palette_Arithmetic_Is_Exact (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   package Arithmetic renames Giflib.Internal.Encoding_Arithmetic;
begin
   for Length in Arithmetic.Palette_Length loop
      declare
         Encoded : constant Arithmetic.Palette_Length :=
           Arithmetic.Encoded_Palette_Length (Length);
         Size : constant Arithmetic.Palette_Size_Code := Arithmetic.Size_Code (Encoded);
         Minimum : constant Natural := Natural (Arithmetic.Minimum_LZW_Code_Size (Encoded));
      begin
         Assert (Encoded >= Length and then Giflib.Palettes.Is_Encodable_Length (Encoded),
                 "palette length was not rounded to an encodable table");
         Assert (2 ** (Size + 1) = Encoded, "packed palette size code is wrong");
         Assert (2 ** Minimum >= Encoded, "minimum LZW code size is too small");
         Assert (Minimum = 2 or else 2 ** (Minimum - 1) < Encoded,
                 "minimum LZW code size is not minimal");
      end;
   end loop;
end Palette_Arithmetic_Is_Exact;

