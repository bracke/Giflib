with Giflib.Errors;

package body Giflib.Internal.Bytes is
   function With_Block (Item : Results.Result; Block : Block_Kind) return Results.Result is
      Revised : Errors.Error;
   begin
      if Results.Succeeded (Item) or else Block = No_Block then
         return Item;
      end if;
      Revised := Item.First_Error;
      Revised.Context.Block := Block;
      return Results.Failure (Revised);
   end With_Block;

   function Read_Byte
     (Object : in out Streams.Source'Class;
      Value : out Byte;
      Block : Block_Kind := No_Block) return Results.Result
   is
      Buffer : Streams.Byte_Array (1 .. 1);
      Outcome : Results.Result;
   begin
      Value := 0;
      Outcome := Streams.Read_Exact (Object, Buffer);
      if Results.Succeeded (Outcome) then
         Value := Buffer (1);
      end if;
      return With_Block (Outcome, Block);
   end Read_Byte;

   function Read_U16_LE
     (Object : in out Streams.Source'Class;
      Value : out Interfaces.Unsigned_16;
      Block : Block_Kind := No_Block) return Results.Result
   is
      Buffer : Streams.Byte_Array (1 .. 2);
      Outcome : Results.Result;
      use type Interfaces.Unsigned_16;
   begin
      Value := 0;
      Outcome := Streams.Read_Exact (Object, Buffer);
      if Results.Succeeded (Outcome) then
         Value := Interfaces.Unsigned_16 (Buffer (1))
           or Interfaces.Shift_Left (Interfaces.Unsigned_16 (Buffer (2)), 8);
      end if;
      return With_Block (Outcome, Block);
   end Read_U16_LE;

   function Write_Byte
     (Object : in out Streams.Destination'Class;
      Value : Byte;
      Block : Block_Kind := No_Block) return Results.Result
   is
      Buffer : constant Streams.Byte_Array := [1 => Value];
   begin
      return With_Block (Streams.Write_All (Object, Buffer), Block);
   end Write_Byte;

   function Write_U16_LE
     (Object : in out Streams.Destination'Class;
      Value : Interfaces.Unsigned_16;
      Block : Block_Kind := No_Block) return Results.Result
   is
      use type Interfaces.Unsigned_16;
      Buffer : constant Streams.Byte_Array :=
        [Byte (Value and 16#FF#), Byte (Interfaces.Shift_Right (Value, 8) and 16#FF#)];
   begin
      return With_Block (Streams.Write_All (Object, Buffer), Block);
   end Write_U16_LE;
end Giflib.Internal.Bytes;
