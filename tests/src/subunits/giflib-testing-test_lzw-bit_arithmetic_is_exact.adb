separate (Giflib.Testing.Test_LZW)
procedure Bit_Arithmetic_Is_Exact (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   package Arithmetic renames Giflib.Internal.LZW_Bit_Arithmetic;
   Packed : Arithmetic.Bit_State := Arithmetic.Append_Code (0, 0, 4, 3);
   First : Giflib.Byte;
   Decoded : Arithmetic.Extracted_Code;
begin
   Packed := Arithmetic.Append_Code
     (Packed.Bits, Arithmetic.Encoder_Append_Count (Packed.Count), 3, 3);
   Packed := Arithmetic.Append_Code
     (Packed.Bits, Arithmetic.Encoder_Append_Count (Packed.Count), 5, 3);
   First := Arithmetic.First_Byte (Packed.Bits);
   Assert (First = 16#5C#, "LSB-first code packing is wrong");

   declare
      Dropped : constant Arithmetic.Bit_State :=
        Arithmetic.Drop_Byte (Packed.Bits, Packed.Count);
      Appended : constant Arithmetic.Bit_State :=
        Arithmetic.Append_Byte
          (0, 0, First);
   begin
      Assert (Dropped.Count = 1 and then Dropped.Bits = 1,
              "encoded bit-buffer drain is wrong");
      Decoded := Arithmetic.Extract (Appended.Bits, Appended.Count, 3);
      Assert (Decoded.Code = 4, "first packed code decoded incorrectly");
      Decoded := Arithmetic.Extract
        (Decoded.State.Bits, Decoded.State.Count, 3);
      Assert (Decoded.Code = 3, "second packed code decoded incorrectly");
   end;
end Bit_Arithmetic_Is_Exact;

