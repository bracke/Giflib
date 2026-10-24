with Giflib.Frames;

package Giflib.Internal.Extension_Arithmetic with SPARK_Mode is
   pragma Pure;
   use type Frames.Disposal_Method;

   subtype Unsigned_16_Value is Natural range 0 .. 65_535;

   function Decode_U16_LE (Low, High : Byte) return Unsigned_16_Value
     with Post =>
       Decode_U16_LE'Result = Natural (Low) + 256 * Natural (High);

   function Low_Byte (Value : Unsigned_16_Value) return Byte
     with Post => Natural (Low_Byte'Result) = Value mod 256;

   function High_Byte (Value : Unsigned_16_Value) return Byte
     with Post => Natural (High_Byte'Result) = Value / 256;

   function Has_Reserved_GCE_Bits (Packed : Byte) return Boolean
     with Post => Has_Reserved_GCE_Bits'Result = (Natural (Packed) / 32 /= 0);

   function Decode_Graphic_Control
     (Packed : Byte;
      Delay_Low : Byte;
      Delay_High : Byte;
      Transparent_Index : Byte) return Frames.Graphic_Control
     with Post =>
       Decode_Graphic_Control'Result.Disposal =
         Frames.Disposal_Method ((Natural (Packed) / 4) mod 8)
       and then Decode_Graphic_Control'Result.User_Input =
         ((Natural (Packed) / 2) mod 2 = 1)
       and then Natural (Decode_Graphic_Control'Result.Delay_CS) =
         Decode_U16_LE (Delay_Low, Delay_High)
       and then Decode_Graphic_Control'Result.Has_Transparency =
         (Natural (Packed) mod 2 = 1)
       and then Decode_Graphic_Control'Result.Transparent_Index =
         Palette_Index (Transparent_Index);

   function Encode_Graphic_Control (Control : Frames.Graphic_Control) return Byte
     with Post =>
       Natural (Encode_Graphic_Control'Result) =
         Natural (Control.Disposal) * 4
           + (if Control.User_Input then 2 else 0)
           + (if Control.Has_Transparency then 1 else 0);
end Giflib.Internal.Extension_Arithmetic;
