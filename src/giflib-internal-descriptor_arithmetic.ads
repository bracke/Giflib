package Giflib.Internal.Descriptor_Arithmetic
  with Pure, SPARK_Mode
is
   subtype Palette_Size_Code is Natural range 0 .. 7;
   subtype Color_Resolution is Positive range 1 .. 8;
   subtype Palette_Length is Natural range 2 .. 256;

   type Logical_Screen_Fields is record
      Has_Global_Palette : Boolean;
      Color_Resolution : Descriptor_Arithmetic.Color_Resolution;
      Global_Palette_Sorted : Boolean;
      Palette_Length : Descriptor_Arithmetic.Palette_Length;
   end record;

   type Image_Fields is record
      Has_Local_Palette : Boolean;
      Interlaced : Boolean;
      Local_Palette_Sorted : Boolean;
      Reserved_Bits : Byte;
      Palette_Length : Descriptor_Arithmetic.Palette_Length;
   end record;

   function Decode_Logical_Screen (Packed : Byte) return Logical_Screen_Fields
     with Post =>
       Decode_Logical_Screen'Result.Has_Global_Palette =
         ((Natural (Packed) / 128) mod 2 = 1)
       and then Decode_Logical_Screen'Result.Color_Resolution =
         Color_Resolution (((Natural (Packed) / 16) mod 8) + 1)
       and then Decode_Logical_Screen'Result.Global_Palette_Sorted =
         ((Natural (Packed) / 8) mod 2 = 1)
       and then Decode_Logical_Screen'Result.Palette_Length =
         2 ** ((Natural (Packed) mod 8) + 1);

   function Decode_Image (Packed : Byte) return Image_Fields
     with Post =>
       Decode_Image'Result.Has_Local_Palette =
         ((Natural (Packed) / 128) mod 2 = 1)
       and then Decode_Image'Result.Interlaced =
         ((Natural (Packed) / 64) mod 2 = 1)
       and then Decode_Image'Result.Local_Palette_Sorted =
         ((Natural (Packed) / 32) mod 2 = 1)
       and then Decode_Image'Result.Reserved_Bits =
         Byte (((Natural (Packed) / 8) mod 4) * 8)
       and then Decode_Image'Result.Palette_Length =
         2 ** ((Natural (Packed) mod 8) + 1);

   function Encode_Logical_Screen
     (Resolution : Color_Resolution;
      Has_Global_Palette : Boolean;
      Global_Palette_Sorted : Boolean;
      Size_Code : Palette_Size_Code) return Byte
     with Post =>
       Natural (Encode_Logical_Screen'Result) =
         (if Has_Global_Palette then 128 else 0)
         + (Natural (Resolution) - 1) * 16
         + (if Global_Palette_Sorted then 8 else 0)
         + Size_Code;

   function Encode_Image
     (Has_Local_Palette : Boolean;
      Interlaced : Boolean;
      Local_Palette_Sorted : Boolean;
      Size_Code : Palette_Size_Code) return Byte
     with Post =>
       Natural (Encode_Image'Result) =
         (if Has_Local_Palette then 128 else 0)
         + (if Interlaced then 64 else 0)
         + (if Local_Palette_Sorted then 32 else 0)
         + Size_Code;
end Giflib.Internal.Descriptor_Arithmetic;
