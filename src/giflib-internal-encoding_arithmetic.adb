package body Giflib.Internal.Encoding_Arithmetic with SPARK_Mode is
   function Encoded_Palette_Length (Length : Palette_Length) return Palette_Length is
   begin
      return
        (if Length = 2 then 2
         elsif Length <= 4 then 4
         elsif Length <= 8 then 8
         elsif Length <= 16 then 16
         elsif Length <= 32 then 32
         elsif Length <= 64 then 64
         elsif Length <= 128 then 128
         else 256);
   end Encoded_Palette_Length;

   function Size_Code (Length : Palette_Length) return Palette_Size_Code is
   begin
      return
        (case Length is
           when 2 => 0,
           when 4 => 1,
           when 8 => 2,
           when 16 => 3,
           when 32 => 4,
           when 64 => 5,
           when 128 => 6,
           when others => 7);
   end Size_Code;

   function Minimum_LZW_Code_Size
     (Length : Palette_Length) return LZW_Arithmetic.Minimum_Code_Size
   is
   begin
      return
        (case Length is
           when 2 | 4 => 2,
           when 8 => 3,
           when 16 => 4,
           when 32 => 5,
           when 64 => 6,
           when 128 => 7,
           when others => 8);
   end Minimum_LZW_Code_Size;
end Giflib.Internal.Encoding_Arithmetic;
