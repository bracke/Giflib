with Interfaces;
with AUnit.Assertions;

with Giflib;
with Giflib.Errors;
with Giflib.Internal.Blocks;
with Giflib.Internal.Bytes;
with Giflib.Internal.Checked_Arithmetic;
with Giflib.Results;
with Giflib.Streams;

package body Giflib_Testing.Test_Blocks is
   use AUnit.Assertions;
   use type Giflib.Block_Kind;
   use type Giflib.Byte;
   use type Giflib.Byte_Count;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Limit_Kind;
   use type Giflib.Source_Offset;
   use type Giflib.Streams.Byte_Array;
   use type Interfaces.Unsigned_16;

   procedure Arithmetic_Is_Checked (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Byte_IO_Is_Little_Endian (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Empty_And_Multiple_Sub_Blocks (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Full_Size_Block_Is_Drained (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Truncation_And_Limits_Fail (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("blocks");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Arithmetic_Is_Checked'Access, "blocks.arithmetic.checked");
      Register_Routine (T, Byte_IO_Is_Little_Endian'Access, "blocks.bytes.little_endian");
      Register_Routine (T, Empty_And_Multiple_Sub_Blocks'Access, "blocks.sub_blocks.empty_and_multiple");
      Register_Routine (T, Full_Size_Block_Is_Drained'Access, "blocks.sub_blocks.255_bytes");
      Register_Routine (T, Truncation_And_Limits_Fail'Access, "blocks.sub_blocks.truncated_and_oversized");
   end Register_Tests;

   procedure Arithmetic_Is_Checked (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Giflib.Internal.Checked_Arithmetic;
      Item : Count_Result;
   begin
      Item := Add (40, 2);
      Assert (Giflib.Results.Succeeded (Item.Outcome) and then Item.Value = 42, "checked add failed");
      Item := Add (Giflib.Byte_Count'Last, 1);
      Assert (Item.Outcome.First_Error.Code = Giflib.Errors.Integer_Overflow, "add overflow was accepted");
      Item := Multiply (6, 7);
      Assert (Giflib.Results.Succeeded (Item.Outcome) and then Item.Value = 42, "checked multiply failed");
      Item := Multiply (Giflib.Byte_Count'Last, 2);
      Assert (Item.Outcome.First_Error.Code = Giflib.Errors.Integer_Overflow,
              "multiply overflow was accepted");
   end Arithmetic_Is_Checked;

   procedure Byte_IO_Is_Little_Endian (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased Giflib.Streams.Byte_Array := [0, 0, 0];
      Destination : Giflib.Streams.Fixed_Buffer_Destination;
      Source : Giflib.Streams.Memory_Source;
      Outcome : Giflib.Results.Result;
      One : Giflib.Byte;
      Two : Interfaces.Unsigned_16;
   begin
      Giflib.Streams.Open (Destination, Storage'Unchecked_Access, Max_Transfer => 1);
      Outcome := Giflib.Internal.Bytes.Write_Byte
        (Destination, 16#AA#, Giflib.Logical_Screen_Descriptor_Block);
      Assert (Giflib.Results.Succeeded (Outcome), "byte write failed");
      Outcome := Giflib.Internal.Bytes.Write_U16_LE
        (Destination, 16#1234#, Giflib.Logical_Screen_Descriptor_Block);
      Assert (Giflib.Results.Succeeded (Outcome), "u16 write failed");
      Assert (Storage = [16#AA#, 16#34#, 16#12#], "little-endian output is wrong");

      Giflib.Streams.Open (Source, Storage'Unchecked_Access, Max_Transfer => 1);
      Outcome := Giflib.Internal.Bytes.Read_Byte (Source, One, Giflib.Logical_Screen_Descriptor_Block);
      Assert (Giflib.Results.Succeeded (Outcome) and then One = 16#AA#, "byte read failed");
      Outcome := Giflib.Internal.Bytes.Read_U16_LE (Source, Two, Giflib.Logical_Screen_Descriptor_Block);
      Assert (Giflib.Results.Succeeded (Outcome) and then Two = 16#1234#, "u16 read failed");
   end Byte_IO_Is_Little_Endian;

   procedure Empty_And_Multiple_Sub_Blocks (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Empty_Input : aliased constant Giflib.Streams.Byte_Array := [0];
      Input : aliased constant Giflib.Streams.Byte_Array := [2, 10, 11, 1, 12, 0];
      Source : Giflib.Streams.Memory_Source;
      Reader : Giflib.Internal.Blocks.Sub_Block_Reader;
      Buffer : Giflib.Streams.Byte_Array (1 .. 4) := [others => 0];
      Count : Giflib.Byte_Count;
      At_End : Boolean;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source, Empty_Input'Unchecked_Access);
      Giflib.Internal.Blocks.Initialize
        (Reader, 10, Giflib.Per_Extension_Byte_Limit, Giflib.Comment_Extension_Block);
      Outcome := Giflib.Internal.Blocks.Read_Data (Reader, Source, Buffer, Count, At_End);
      Assert (Giflib.Results.Succeeded (Outcome), "empty sub-block chain failed");
      Assert (Count = 0 and then At_End and then Giflib.Internal.Blocks.Finished (Reader),
              "empty sub-block chain has wrong state");

      Giflib.Streams.Open (Source, Input'Unchecked_Access, Max_Transfer => 1);
      Giflib.Internal.Blocks.Initialize
        (Reader, 3, Giflib.Per_Extension_Byte_Limit, Giflib.Comment_Extension_Block);
      Outcome := Giflib.Internal.Blocks.Read_Data (Reader, Source, Buffer, Count, At_End);
      Assert (Giflib.Results.Succeeded (Outcome) and then Count = 2, "first sub-block failed");
      Assert (Buffer (1 .. 2) = [10, 11], "first sub-block data is wrong");
      Outcome := Giflib.Internal.Blocks.Read_Data (Reader, Source, Buffer, Count, At_End);
      Assert (Giflib.Results.Succeeded (Outcome) and then Count = 1, "second sub-block failed");
      Assert (Buffer (1) = 12, "second sub-block data is wrong");
      Outcome := Giflib.Internal.Blocks.Read_Data (Reader, Source, Buffer, Count, At_End);
      Assert (Giflib.Results.Succeeded (Outcome) and then Count = 0 and then At_End,
              "sub-block terminator failed");
      Assert (Giflib.Internal.Blocks.Total_Bytes (Reader) = 3, "sub-block byte count is wrong");
   end Empty_And_Multiple_Sub_Blocks;

   function Full_Block_Stream return Giflib.Streams.Byte_Array is
      Item : Giflib.Streams.Byte_Array (1 .. 257);
   begin
      Item (1) := 255;
      for I in 1 .. 255 loop
         Item (I + 1) := Giflib.Byte (I mod 256);
      end loop;
      Item (257) := 0;
      return Item;
   end Full_Block_Stream;

   procedure Full_Size_Block_Is_Drained (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Input : aliased constant Giflib.Streams.Byte_Array := Full_Block_Stream;
      Source : Giflib.Streams.Memory_Source;
      Reader : Giflib.Internal.Blocks.Sub_Block_Reader;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source, Input'Unchecked_Access, Max_Transfer => 7);
      Giflib.Internal.Blocks.Initialize
        (Reader, 255, Giflib.Compressed_Byte_Limit, Giflib.Image_Data_Block);
      Outcome := Giflib.Internal.Blocks.Drain (Reader, Source);
      Assert (Giflib.Results.Succeeded (Outcome), "255-byte sub-block did not drain");
      Assert (Giflib.Internal.Blocks.Total_Bytes (Reader) = 255, "255-byte count is wrong");
      Assert (Source.Offset = 257 and then Giflib.Internal.Blocks.Finished (Reader),
              "255-byte stream boundary is wrong");
   end Full_Size_Block_Is_Drained;

   procedure Truncation_And_Limits_Fail (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Truncated : aliased constant Giflib.Streams.Byte_Array := [3, 1, 2];
      Oversized : aliased constant Giflib.Streams.Byte_Array := [3, 1, 2, 3, 0];
      Source : Giflib.Streams.Memory_Source;
      Reader : Giflib.Internal.Blocks.Sub_Block_Reader;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source, Truncated'Unchecked_Access);
      Giflib.Internal.Blocks.Initialize
        (Reader, 10, Giflib.Compressed_Byte_Limit, Giflib.Image_Data_Block);
      Outcome := Giflib.Internal.Blocks.Drain (Reader, Source);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Truncated_Block, "truncation has wrong error");
      Assert (Outcome.First_Error.Context.Block = Giflib.Image_Data_Block,
              "truncation lost block context");

      Giflib.Streams.Open (Source, Oversized'Unchecked_Access);
      Giflib.Internal.Blocks.Initialize
        (Reader, 2, Giflib.Per_Extension_Byte_Limit, Giflib.Comment_Extension_Block);
      Outcome := Giflib.Internal.Blocks.Drain (Reader, Source);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded, "oversized chain was accepted");
      Assert (Outcome.First_Error.Context.Limit = Giflib.Per_Extension_Byte_Limit,
              "oversized chain lost limit context");
      Assert (Source.Offset = 1, "oversized payload was read before rejection");
   end Truncation_And_Limits_Fail;
end Giflib_Testing.Test_Blocks;
