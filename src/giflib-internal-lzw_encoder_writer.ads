with Interfaces;
with Giflib.Internal.Blocks;
with Giflib.Internal.LZW_Arithmetic;
with Giflib.Internal.Work_Budgets;
with Giflib.Results;
with Giflib.Streams;

package Giflib.Internal.LZW_Encoder_Writer
  with Preelaborate
is
   type Writer_State is (Open, Finished, Failed);
   type Code_Writer is limited private;

   function State (Object : Code_Writer) return Writer_State;

   function Put
     (Object : in out Code_Writer;
      Writer : in out Blocks.Sub_Block_Writer;
      Destination : in out Streams.Destination'Class;
      Work : in out Work_Budgets.Meter;
      Code : LZW_Arithmetic.Code_Value;
      Width : LZW_Arithmetic.Active_Code_Width) return Results.Result
     with Pre => Natural (Code) < 2 ** Natural (Width),
          Post =>
            (if Results.Succeeded (Put'Result)
             then State (Object) = Open
             else State (Object) /= Open);

   function Finish
     (Object : in out Code_Writer;
      Writer : in out Blocks.Sub_Block_Writer;
      Destination : in out Streams.Destination'Class) return Results.Result
     with Post => State (Object) /= Open;

private
   type Code_Writer is limited record
      Bits : Interfaces.Unsigned_32 := 0;
      Bit_Count : Natural := 0;
      Pending : Streams.Byte_Array (1 .. 255) := [others => 0];
      Pending_Count : Natural range 0 .. 255 := 0;
      Current_State : Writer_State := Open;
   end record;
end Giflib.Internal.LZW_Encoder_Writer;
