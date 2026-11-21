with Interfaces;
with Giflib.Errors;
with Giflib.Internal.Blocks;
with Giflib.Internal.LZW_Arithmetic;
with Giflib.Internal.Work_Budgets;
with Giflib.Streams;

package Giflib.Internal.LZW_Decoder_Reader
  with Preelaborate
is
   pragma Warnings
     (Off, "aspect * not enforced on inlined subprogram *");
   type Code_Reader is limited private;

   function Ordinal (Object : Code_Reader) return Byte_Count;
   function Failure_Error (Object : Code_Reader) return Errors.Error;

   type Read_Status is (Read_Ready, Read_Failed);

   type Read_Parameters is record
      Code_Width : LZW_Arithmetic.Active_Code_Width;
      Frame : Frame_Ordinal := 0;
      Output_Length : Natural;
      Output_Position : Natural;
   end record;

   function Next_Code
     (Reader : in out Code_Reader;
      Source : in out Streams.Source'Class;
      Blocks_Reader : in out Blocks.Sub_Block_Reader;
      Work : in out Work_Budgets.Meter;
      Pending_Work : in out Byte_Count;
      Parameters : Read_Parameters;
      Value : out LZW_Arithmetic.Code_Value) return Read_Status
     with Pre => Parameters.Output_Position <= Parameters.Output_Length
                 and then Ordinal (Reader) < Byte_Count'Last,
          Post => Ordinal (Reader) in
                    Ordinal (Reader)'Old .. Ordinal (Reader)'Old + 1
                  and
                    (Next_Code'Result /= Read_Ready
                     or Ordinal (Reader) = Ordinal (Reader)'Old + 1);
   pragma Inline_Always (Next_Code);
   pragma Warnings
     (On, "aspect * not enforced on inlined subprogram *");
private
   type Code_Reader is limited record
      Bit_Buffer : Interfaces.Unsigned_32 := 0;
      Bit_Count : Natural := 0;
      Buffer : Streams.Byte_Array (1 .. 255) := [others => 0];
      Count : Natural := 0;
      Position : Natural := 0;
      Code_Ordinal : Byte_Count := 0;
      Last_Error : Errors.Error := Errors.No_Error_Value;
   end record;
end Giflib.Internal.LZW_Decoder_Reader;
