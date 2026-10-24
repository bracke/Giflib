with Giflib.Internal.LZW_Arithmetic;
with Giflib.Palettes;

package Giflib.Internal.Encoding_Arithmetic with SPARK_Mode is
   pragma Pure;

   subtype Palette_Length is Natural range 2 .. 256;
   subtype Palette_Size_Code is Natural range 0 .. 7;

   function Encoded_Palette_Length (Length : Palette_Length) return Palette_Length
     with Post =>
       Palettes.Is_Encodable_Length (Encoded_Palette_Length'Result)
       and then Encoded_Palette_Length'Result >= Length
       and then
         (Encoded_Palette_Length'Result = 2
          or else Encoded_Palette_Length'Result / 2 < Length);

   function Size_Code (Length : Palette_Length) return Palette_Size_Code
     with Pre => Palettes.Is_Encodable_Length (Length),
          Post => 2 ** (Size_Code'Result + 1) = Length;

   function Minimum_LZW_Code_Size
     (Length : Palette_Length) return LZW_Arithmetic.Minimum_Code_Size
     with Pre => Palettes.Is_Encodable_Length (Length),
          Post =>
            Minimum_LZW_Code_Size'Result =
              (case Length is
                 when 2 | 4 => 2,
                 when 8 => 3,
                 when 16 => 4,
                 when 32 => 5,
                 when 64 => 6,
                 when 128 => 7,
                 when others => 8);
end Giflib.Internal.Encoding_Arithmetic;
