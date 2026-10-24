package body Giflib.Internal.Descriptor_Arithmetic
  with SPARK_Mode
is
   function Decode_Logical_Screen (Packed : Byte) return Logical_Screen_Fields is
     ((Has_Global_Palette => (Natural (Packed) / 128) mod 2 = 1,
       Color_Resolution => Color_Resolution (((Natural (Packed) / 16) mod 8) + 1),
       Global_Palette_Sorted => (Natural (Packed) / 8) mod 2 = 1,
       Palette_Length => 2 ** ((Natural (Packed) mod 8) + 1)));

   function Decode_Image (Packed : Byte) return Image_Fields is
     ((Has_Local_Palette => (Natural (Packed) / 128) mod 2 = 1,
       Interlaced => (Natural (Packed) / 64) mod 2 = 1,
       Local_Palette_Sorted => (Natural (Packed) / 32) mod 2 = 1,
       Reserved_Bits => Byte (((Natural (Packed) / 8) mod 4) * 8),
       Palette_Length => 2 ** ((Natural (Packed) mod 8) + 1)));

   function Encode_Logical_Screen
     (Resolution : Color_Resolution;
      Has_Global_Palette : Boolean;
      Global_Palette_Sorted : Boolean;
      Size_Code : Palette_Size_Code) return Byte
   is
     (Byte
        ((if Has_Global_Palette then 128 else 0)
         + (Natural (Resolution) - 1) * 16
         + (if Global_Palette_Sorted then 8 else 0)
         + Size_Code));

   function Encode_Image
     (Has_Local_Palette : Boolean;
      Interlaced : Boolean;
      Local_Palette_Sorted : Boolean;
      Size_Code : Palette_Size_Code) return Byte
   is
     (Byte
        ((if Has_Local_Palette then 128 else 0)
         + (if Interlaced then 64 else 0)
         + (if Local_Palette_Sorted then 32 else 0)
         + Size_Code));
end Giflib.Internal.Descriptor_Arithmetic;
