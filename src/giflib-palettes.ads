package Giflib.Palettes is
   pragma Pure;

   type RGB_Color is record
      Red : Byte := 0;
      Green : Byte := 0;
      Blue : Byte := 0;
   end record;

   type Color_Array is array (Palette_Index) of RGB_Color;

   type Palette is record
      Length : Natural range 0 .. 256 := 0;
      Colors : Color_Array := [others => (others => 0)];
   end record;

   function Is_Encodable_Length (Length : Natural) return Boolean is
     (Length in 2 | 4 | 8 | 16 | 32 | 64 | 128 | 256);

   function Contains (Item : Palette; Index : Palette_Index) return Boolean is
     (Natural (Index) < Item.Length);

   function Same_Entries (Left, Right : Palette) return Boolean is
     (if Left.Length /= Right.Length then False
      elsif Left.Length = 0 then True
      else (for all I in Palette_Index range 0 .. Palette_Index (Left.Length - 1) =>
              Left.Colors (I) = Right.Colors (I)));
end Giflib.Palettes;
