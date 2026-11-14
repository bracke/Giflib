with Interfaces;
with AUnit.Assertions;

with Giflib.Errors;
with Giflib.Internal.Block_Arithmetic;
with Giflib.Internal.Blocks;
with Giflib.Internal.Budget_Arithmetic;
with Giflib.Internal.Bytes;
with Giflib.Testing.Checked_Arithmetic;
with Giflib.Results;
with Giflib.Streams;

package body Giflib.Testing.Test_Blocks is
   use AUnit.Assertions;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Streams.Byte_Array;
   use type Interfaces.Unsigned_16;

   procedure Arithmetic_Is_Checked (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Block_State_Arithmetic_Is_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Byte_IO_Is_Little_Endian (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Empty_And_Multiple_Sub_Blocks (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Full_Size_Block_Is_Drained (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Truncation_And_Limits_Fail (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Writer_Enforces_Wire_Limit (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("blocks");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Arithmetic_Is_Checked'Access, "blocks.arithmetic.checked");
      Register_Routine (T, Block_State_Arithmetic_Is_Bounded'Access,
                        "blocks.arithmetic.state");
      Register_Routine (T, Byte_IO_Is_Little_Endian'Access, "blocks.bytes.little_endian");
      Register_Routine (T, Empty_And_Multiple_Sub_Blocks'Access, "blocks.sub_blocks.empty_and_multiple");
      Register_Routine (T, Full_Size_Block_Is_Drained'Access, "blocks.sub_blocks.255_bytes");
      Register_Routine (T, Truncation_And_Limits_Fail'Access, "blocks.sub_blocks.truncated_and_oversized");
      Register_Routine (T, Writer_Enforces_Wire_Limit'Access,
                        "blocks.sub_blocks.writer_wire_limit");
   end Register_Tests;

   procedure Writer_Enforces_Wire_Limit
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Block_State_Arithmetic_Is_Bounded
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Arithmetic_Is_Checked (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Byte_IO_Is_Little_Endian (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Empty_And_Multiple_Sub_Blocks (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

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

   procedure Full_Size_Block_Is_Drained (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Truncation_And_Limits_Fail (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
end Giflib.Testing.Test_Blocks;
