package body Giflib.Internal.LZW_Arithmetic with SPARK_Mode is
   function Initialize (Minimum : Minimum_Code_Size) return Initial_Code_State is
      Clear : constant Clear_Code_Value :=
        (case Minimum is
           when 2 => 4,
           when 3 => 8,
           when 4 => 16,
           when 5 => 32,
           when 6 => 64,
           when 7 => 128,
           when 8 => 256);
   begin
      return
        (Clear_Code => Clear,
         End_Code => Clear + 1,
         First_Free_Code => Clear + 2,
         Width => Minimum + 1);
   end Initialize;

   function Decoder_Width_After_Insert
     (Next_Free : Next_Code_Value;
      Width : Active_Code_Width) return Active_Code_Width
   is
   begin
      return
        (if Next_Free = 2 ** Width and then Width < Active_Code_Width'Last
         then Width + 1
         else Width);
   end Decoder_Width_After_Insert;

   function Encoder_Width_After_Insert
     (Next_Free : Next_Code_Value;
      Width : Active_Code_Width) return Active_Code_Width
   is
   begin
      return
        (if Next_Free > 2 ** Width and then Width < Active_Code_Width'Last
         then Width + 1
         else Width);
   end Encoder_Width_After_Insert;

   function Hash_Start (Prefix : Code_Value; Suffix : Byte) return Hash_Slot is
   begin
      return (Prefix * 257 + Natural (Suffix)) mod Hash_Size;
   end Hash_Start;

   function Next_Hash_Slot (Current : Hash_Slot) return Hash_Slot is
   begin
      return (if Current = Hash_Slot'Last then Hash_Slot'First else Current + 1);
   end Next_Hash_Slot;

   function Can_Push (Count : Stack_Count) return Boolean is
     (Count < Dictionary_Size);

   function Push_Count (Count : Stack_Count) return Stack_Count is
     (Count + 1);

   function Can_Follow
     (Current : Code_Value;
      First_Free : Next_Code_Value;
      Next_Free : Next_Code_Value;
      Count : Stack_Count) return Boolean
   is
     (Current >= First_Free
      and then Current < Next_Free
      and then Can_Push (Count));

   function Can_Insert (Next_Free : Next_Code_Value) return Boolean is
     (Next_Free < Dictionary_Size);

   function After_Insert (Next_Free : Next_Code_Value) return Next_Code_Value is
     (Next_Free + 1);
end Giflib.Internal.LZW_Arithmetic;
