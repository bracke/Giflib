package body Giflib.Internal.Extension_Arithmetic with SPARK_Mode is
   function Decode_U16_LE (Low, High : Byte) return Unsigned_16_Value is
     (Natural (Low) + 256 * Natural (High));

   function Low_Byte (Value : Unsigned_16_Value) return Byte is
     (Byte (Value mod 256));

   function High_Byte (Value : Unsigned_16_Value) return Byte is
     (Byte (Value / 256));

   function Has_Reserved_GCE_Bits (Packed : Byte) return Boolean is
     (Natural (Packed) / 32 /= 0);

   function Decode_Graphic_Control
     (Packed : Byte;
      Delay_Low : Byte;
      Delay_High : Byte;
      Transparent_Index : Byte) return Frames.Graphic_Control
   is
   begin
      return
        (Disposal => Frames.Disposal_Method ((Natural (Packed) / 4) mod 8),
         User_Input => (Natural (Packed) / 2) mod 2 = 1,
         Delay_CS => Delay_Centiseconds (Decode_U16_LE (Delay_Low, Delay_High)),
         Has_Transparency => Natural (Packed) mod 2 = 1,
         Transparent_Index => Palette_Index (Transparent_Index));
   end Decode_Graphic_Control;

   function Encode_Graphic_Control (Control : Frames.Graphic_Control) return Byte is
   begin
      return Byte
        (Natural (Control.Disposal) * 4
         + (if Control.User_Input then 2 else 0)
         + (if Control.Has_Transparency then 1 else 0));
   end Encode_Graphic_Control;
end Giflib.Internal.Extension_Arithmetic;
