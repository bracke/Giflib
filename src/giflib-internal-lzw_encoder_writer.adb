with Giflib.Internal.Diagnostics;
with Giflib.Internal.LZW_Bit_Arithmetic;
with Giflib.Internal.LZW_Work;

package body Giflib.Internal.LZW_Encoder_Writer is
   use type Blocks.Write_Status;
   function State (Object : Code_Writer) return Writer_State is
     (Object.Current_State);

   function Failure_Error (Object : Code_Writer) return Errors.Error is
     (Object.Last_Error);

   function Invalid_State
     (Destination : Streams.Destination'Class) return Results.Result is
     (Results.Failure
        (Errors.Make
           (Errors.Invalid_State,
            Diagnostics.At_Destination (Destination))));

   function Put_Byte
     (Object : in out Code_Writer;
      Writer : in out Blocks.Sub_Block_Writer;
      Destination : in out Streams.Destination'Class;
      Value : Byte) return Boolean
   is
   begin
      if Blocks.Put_Byte_Validated (Writer, Destination, Value)
        /= Blocks.Write_Ready
      then
         Object.Last_Error := Blocks.Failure_Error (Writer);
         return False;
      end if;
      return True;
   end Put_Byte;
   pragma Inline_Always (Put_Byte);

   function Put
     (Object : in out Code_Writer;
      Writer : in out Blocks.Sub_Block_Writer;
      Destination : in out Streams.Destination'Class;
      Work : in out Work_Budgets.Meter;
      Code : LZW_Arithmetic.Code_Value;
      Width : LZW_Arithmetic.Active_Code_Width) return Results.Result
   is
   begin
      if Object.Current_State /= Open then
         return Invalid_State (Destination);
      end if;
      if not LZW_Work.Try_Charge (Work, 1) then
         Object.Current_State := Failed;
         declare
            Outcome : constant Results.Result :=
              LZW_Work.Failure (Destination, Work);
         begin
            Object.Last_Error := Outcome.First_Error;
            return Outcome;
         end;
      end if;
      declare
         Succeeded : constant Boolean := Put_Validated
           (Object, Writer, Destination, Code, Width);
      begin
         return
           (if Succeeded
            then Results.Success
            else Results.Failure (Object.Last_Error));
      end;
   end Put;

   function Put_Validated
     (Object : in out Code_Writer;
      Writer : in out Blocks.Sub_Block_Writer;
      Destination : in out Streams.Destination'Class;
      Code : LZW_Arithmetic.Code_Value;
      Width : LZW_Arithmetic.Active_Code_Width) return Boolean
   is
      State : LZW_Bit_Arithmetic.Bit_State;
   begin
      State := LZW_Bit_Arithmetic.Append_Code
        (Object.Bits,
         LZW_Bit_Arithmetic.Encoder_Append_Count (Object.Bit_Count),
         LZW_Bit_Arithmetic.Code_Value (Code),
         LZW_Bit_Arithmetic.Code_Width (Width));
      Object.Bits := State.Bits;
      Object.Bit_Count := State.Count;
      if Object.Bit_Count >= 16 then
         if Blocks.Put_Two_Bytes_Validated
           (Writer, Destination,
            LZW_Bit_Arithmetic.First_Byte (Object.Bits),
            LZW_Bit_Arithmetic.First_Byte
              (Interfaces.Shift_Right (Object.Bits, 8)))
           /= Blocks.Write_Ready
         then
            Object.Last_Error := Blocks.Failure_Error (Writer);
            Object.Current_State := Failed;
            return False;
         end if;
         Object.Bits := Interfaces.Shift_Right (Object.Bits, 16);
         Object.Bit_Count := Object.Bit_Count - 16;
      end if;
      while Object.Bit_Count >= 8 loop
         if not Put_Byte
           (Object, Writer, Destination,
            LZW_Bit_Arithmetic.First_Byte (Object.Bits))
         then
            Object.Current_State := Failed;
            return False;
         end if;
         State := LZW_Bit_Arithmetic.Drop_Byte
           (Object.Bits, LZW_Bit_Arithmetic.Bit_Count (Object.Bit_Count));
         Object.Bits := State.Bits;
         Object.Bit_Count := State.Count;
      end loop;
      return True;
   end Put_Validated;

   function Finish
     (Object : in out Code_Writer;
      Writer : in out Blocks.Sub_Block_Writer;
      Destination : in out Streams.Destination'Class) return Results.Result
   is
   begin
      if Object.Current_State /= Open then
         return Invalid_State (Destination);
      end if;
      if Object.Bit_Count > 0 then
         if not Put_Byte
           (Object, Writer, Destination,
            LZW_Bit_Arithmetic.First_Byte (Object.Bits))
         then
            Object.Current_State := Failed;
            return Results.Failure (Object.Last_Error);
         end if;
         Object.Bits := 0;
         Object.Bit_Count := 0;
      end if;
      Object.Current_State := Finished;
      return Results.Success;
   end Finish;
end Giflib.Internal.LZW_Encoder_Writer;
