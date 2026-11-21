with Interfaces;
with Giflib.Errors;
with Giflib.Internal.Blocks;
with Giflib.Internal.LZW_Arithmetic;
with Giflib.Internal.Work_Budgets;
with Giflib.Results;
with Giflib.Streams;

package Giflib.Internal.LZW_Encoder_Writer
  with Preelaborate
is
   pragma Warnings
     (Off, "aspect * not enforced on inlined subprogram *");
   type Writer_State is (Open, Finished, Failed);
   type Code_Writer is limited private;

   function State (Object : Code_Writer) return Writer_State;
   function Failure_Error (Object : Code_Writer) return Errors.Error
     with Pre => State (Object) = Failed;

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

   function Put_Validated
     (Object : in out Code_Writer;
      Writer : in out Blocks.Sub_Block_Writer;
      Destination : in out Streams.Destination'Class;
      Code : LZW_Arithmetic.Code_Value;
      Width : LZW_Arithmetic.Active_Code_Width) return Boolean
     with Pre => State (Object) = Open
                   and then Natural (Code) < 2 ** Natural (Width),
          Post =>
            (if Put_Validated'Result
             then State (Object) = Open
             else State (Object) = Failed);
   pragma Inline_Always (Put_Validated);
   pragma Warnings
     (On, "aspect * not enforced on inlined subprogram *");
   function Finish
     (Object : in out Code_Writer;
      Writer : in out Blocks.Sub_Block_Writer;
      Destination : in out Streams.Destination'Class) return Results.Result
     with Post => State (Object) /= Open;

private
   type Code_Writer is limited record
      Bits : Interfaces.Unsigned_32 := 0;
      Bit_Count : Natural := 0;
      Current_State : Writer_State := Open;
      Last_Error : Errors.Error := Errors.No_Error_Value;
   end record;
end Giflib.Internal.LZW_Encoder_Writer;
