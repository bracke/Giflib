package Giflib.Internal.LZW_Arithmetic with SPARK_Mode is
   pragma Pure;

   subtype Minimum_Code_Size is Natural range 2 .. 8;
   subtype Active_Code_Width is Natural range 3 .. 12;
   subtype Code_Value is Natural range 0 .. 4_095;
   subtype Clear_Code_Value is Code_Value range 4 .. 256;
   subtype Next_Code_Value is Natural range 6 .. 4_096;
   subtype Stack_Count is Natural range 0 .. 4_096;

   Dictionary_Size : constant := 4_096;
   Hash_Size : constant := 8_192;
   subtype Hash_Slot is Natural range 0 .. Hash_Size - 1;

   type Initial_Code_State is record
      Clear_Code : Clear_Code_Value;
      End_Code : Code_Value;
      First_Free_Code : Next_Code_Value;
      Width : Active_Code_Width;
   end record;

   function Initialize (Minimum : Minimum_Code_Size) return Initial_Code_State
     with Post =>
       Initialize'Result.Clear_Code =
         (case Minimum is
            when 2 => 4,
            when 3 => 8,
            when 4 => 16,
            when 5 => 32,
            when 6 => 64,
            when 7 => 128,
            when 8 => 256)
       and then Initialize'Result.End_Code = Initialize'Result.Clear_Code + 1
       and then Initialize'Result.First_Free_Code = Initialize'Result.Clear_Code + 2
       and then Initialize'Result.Width = Minimum + 1;

   --  Decoder allocation precedes its width change. Encoder allocation trails
   --  the code emission that observes the change, hence the distinct boundary.
   function Decoder_Width_After_Insert
     (Next_Free : Next_Code_Value;
      Width : Active_Code_Width) return Active_Code_Width
     with Post =>
       Decoder_Width_After_Insert'Result =
         (if Next_Free = 2 ** Width and then Width < Active_Code_Width'Last
          then Width + 1
          else Width);

   function Encoder_Width_After_Insert
     (Next_Free : Next_Code_Value;
      Width : Active_Code_Width) return Active_Code_Width
     with Post =>
       Encoder_Width_After_Insert'Result =
         (if Next_Free > 2 ** Width and then Width < Active_Code_Width'Last
          then Width + 1
          else Width);

   function Hash_Start (Prefix : Code_Value; Suffix : Byte) return Hash_Slot
     with Post =>
       Hash_Start'Result =
         (Prefix * 257 + Natural (Suffix)) mod Hash_Size;

   function Next_Hash_Slot (Current : Hash_Slot) return Hash_Slot
     with Post =>
       Next_Hash_Slot'Result =
         (if Current = Hash_Slot'Last then Hash_Slot'First else Current + 1);

   function Can_Push (Count : Stack_Count) return Boolean
     with Post => Can_Push'Result = (Count < Dictionary_Size);

   function Push_Count (Count : Stack_Count) return Stack_Count
     with Pre => Can_Push (Count),
          Post => Push_Count'Result = Count + 1;

   function Can_Follow
     (Current : Code_Value;
      First_Free : Next_Code_Value;
      Next_Free : Next_Code_Value;
      Count : Stack_Count) return Boolean
     with Post =>
       Can_Follow'Result =
         (Current >= First_Free
          and then Current < Next_Free
          and then Can_Push (Count));

   function Can_Insert (Next_Free : Next_Code_Value) return Boolean
     with Post => Can_Insert'Result = (Next_Free < Dictionary_Size);

   function After_Insert (Next_Free : Next_Code_Value) return Next_Code_Value
     with Pre => Can_Insert (Next_Free),
          Post => After_Insert'Result = Next_Free + 1;
end Giflib.Internal.LZW_Arithmetic;
