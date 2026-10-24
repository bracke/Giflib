with Interfaces;

package Giflib.Internal.LZW_Bit_Arithmetic
  with Pure, SPARK_Mode
is
   use type Interfaces.Unsigned_32;

   subtype Bit_Count is Natural range 0 .. 19;
   subtype Decoder_Append_Count is Bit_Count range 0 .. 11;
   subtype Encoder_Append_Count is Bit_Count range 0 .. 7;
   subtype Code_Width is Natural range 2 .. 12;
   subtype Code_Value is Natural range 0 .. 4_095;

   type Bit_State is record
      Bits : Interfaces.Unsigned_32;
      Count : Bit_Count;
   end record;

   type Extracted_Code is record
      Code : Code_Value;
      State : Bit_State;
   end record;

   function Width_Mask (Width : Code_Width) return Interfaces.Unsigned_32
     with Post =>
       Width_Mask'Result =
         Interfaces.Shift_Left (Interfaces.Unsigned_32 (1), Width) - 1;

   function Append_Byte
     (Bits : Interfaces.Unsigned_32;
      Count : Decoder_Append_Count;
      Value : Byte) return Bit_State
     with Post =>
       Append_Byte'Result.Bits =
         (Bits or Interfaces.Shift_Left (Interfaces.Unsigned_32 (Value), Count))
       and then Append_Byte'Result.Count = Count + 8;

   function Extract
     (Bits : Interfaces.Unsigned_32;
      Count : Bit_Count;
      Width : Code_Width) return Extracted_Code
     with Pre => Count >= Width,
          Post =>
            Extract'Result.Code =
              Natural (Bits and Width_Mask (Width))
            and then Extract'Result.State.Bits =
              Interfaces.Shift_Right (Bits, Width)
            and then Extract'Result.State.Count = Count - Width;

   function Append_Code
     (Bits : Interfaces.Unsigned_32;
      Count : Encoder_Append_Count;
      Code : Code_Value;
      Width : Code_Width) return Bit_State
     with Pre => Code < 2 ** Width,
          Post =>
            Append_Code'Result.Bits =
              (Bits or Interfaces.Shift_Left (Interfaces.Unsigned_32 (Code), Count))
            and then Append_Code'Result.Count = Count + Width;

   function First_Byte (Bits : Interfaces.Unsigned_32) return Byte
     with Post =>
       Interfaces.Unsigned_32 (First_Byte'Result) =
         (Bits and Interfaces.Unsigned_32 (16#FF#));

   function Drop_Byte
     (Bits : Interfaces.Unsigned_32;
      Count : Bit_Count) return Bit_State
     with Pre => Count >= 8,
          Post =>
            Drop_Byte'Result.Bits = Interfaces.Shift_Right (Bits, 8)
            and then Drop_Byte'Result.Count = Count - 8;
end Giflib.Internal.LZW_Bit_Arithmetic;
