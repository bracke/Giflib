package body Giflib.Internal.LZW_Bit_Arithmetic
  with SPARK_Mode
is
   function Width_Mask (Width : Code_Width) return Interfaces.Unsigned_32 is
     (Interfaces.Shift_Left (Interfaces.Unsigned_32 (1), Width) - 1);

   function Append_Byte
     (Bits : Interfaces.Unsigned_32;
      Count : Decoder_Append_Count;
      Value : Byte) return Bit_State
   is
     ((Bits => Bits or Interfaces.Shift_Left (Interfaces.Unsigned_32 (Value), Count),
       Count => Count + 8));

   function Extract
     (Bits : Interfaces.Unsigned_32;
      Count : Bit_Count;
      Width : Code_Width) return Extracted_Code
   is
     ((Code => Code_Value (Bits and Width_Mask (Width)),
       State =>
         (Bits => Interfaces.Shift_Right (Bits, Width),
          Count => Count - Width)));

   function Append_Code
     (Bits : Interfaces.Unsigned_32;
      Count : Encoder_Append_Count;
      Code : Code_Value;
      Width : Code_Width) return Bit_State
   is
     ((Bits => Bits or Interfaces.Shift_Left (Interfaces.Unsigned_32 (Code), Count),
       Count => Count + Width));

   function First_Byte (Bits : Interfaces.Unsigned_32) return Byte is
     (Byte (Bits and Interfaces.Unsigned_32 (16#FF#)));

   function Drop_Byte
     (Bits : Interfaces.Unsigned_32;
      Count : Bit_Count) return Bit_State
   is
     ((Bits => Interfaces.Shift_Right (Bits, 8), Count => Count - 8));
end Giflib.Internal.LZW_Bit_Arithmetic;
