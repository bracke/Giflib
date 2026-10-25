with Giflib.Errors;
with Giflib.Internal.Diagnostics;
with Giflib.Internal.LZW_Bit_Arithmetic;
with Giflib.Internal.LZW_Work;

package body Giflib.Internal.LZW_Encoder_Writer is
   function State (Object : Code_Writer) return Writer_State is
     (Object.Current_State);

   function Invalid_State
     (Destination : Streams.Destination'Class) return Results.Result is
     (Results.Failure
        (Errors.Make
           (Errors.Invalid_State,
            Diagnostics.At_Destination (Destination))));

   function Flush
     (Object : in out Code_Writer;
      Writer : in out Blocks.Sub_Block_Writer;
      Destination : in out Streams.Destination'Class) return Results.Result
   is
      Outcome : Results.Result;
   begin
      if Object.Pending_Count = 0 then
         return Results.Success;
      end if;
      Outcome := Blocks.Write_Data
        (Writer, Destination, Object.Pending (1 .. Object.Pending_Count));
      if Results.Succeeded (Outcome) then
         Object.Pending_Count := 0;
      end if;
      return Outcome;
   end Flush;

   function Put_Byte
     (Object : in out Code_Writer;
      Writer : in out Blocks.Sub_Block_Writer;
      Destination : in out Streams.Destination'Class;
      Value : Byte) return Results.Result is
   begin
      Object.Pending_Count := Object.Pending_Count + 1;
      Object.Pending (Object.Pending_Count) := Value;
      return
        (if Object.Pending_Count = Object.Pending'Length
         then Flush (Object, Writer, Destination)
         else Results.Success);
   end Put_Byte;

   function Put
     (Object : in out Code_Writer;
      Writer : in out Blocks.Sub_Block_Writer;
      Destination : in out Streams.Destination'Class;
      Work : in out Work_Budgets.Meter;
      Code : LZW_Arithmetic.Code_Value;
      Width : LZW_Arithmetic.Active_Code_Width) return Results.Result
   is
      Outcome : Results.Result;
      State : LZW_Bit_Arithmetic.Bit_State;
   begin
      if Object.Current_State /= Open then
         return Invalid_State (Destination);
      end if;
      Outcome := LZW_Work.Charge (Destination, Work, 1);
      if not Results.Succeeded (Outcome) then
         Object.Current_State := Failed;
         return Outcome;
      end if;
      State := LZW_Bit_Arithmetic.Append_Code
        (Object.Bits,
         LZW_Bit_Arithmetic.Encoder_Append_Count (Object.Bit_Count),
         LZW_Bit_Arithmetic.Code_Value (Code),
         LZW_Bit_Arithmetic.Code_Width (Width));
      Object.Bits := State.Bits;
      Object.Bit_Count := State.Count;
      while Object.Bit_Count >= 8 loop
         Outcome := Put_Byte
           (Object, Writer, Destination,
            LZW_Bit_Arithmetic.First_Byte (Object.Bits));
         if not Results.Succeeded (Outcome) then
            Object.Current_State := Failed;
            return Outcome;
         end if;
         State := LZW_Bit_Arithmetic.Drop_Byte
           (Object.Bits, LZW_Bit_Arithmetic.Bit_Count (Object.Bit_Count));
         Object.Bits := State.Bits;
         Object.Bit_Count := State.Count;
      end loop;
      return Results.Success;
   end Put;

   function Finish
     (Object : in out Code_Writer;
      Writer : in out Blocks.Sub_Block_Writer;
      Destination : in out Streams.Destination'Class) return Results.Result
   is
      Outcome : Results.Result;
   begin
      if Object.Current_State /= Open then
         return Invalid_State (Destination);
      end if;
      if Object.Bit_Count > 0 then
         Outcome := Put_Byte
           (Object, Writer, Destination,
            LZW_Bit_Arithmetic.First_Byte (Object.Bits));
         if not Results.Succeeded (Outcome) then
            Object.Current_State := Failed;
            return Outcome;
         end if;
         Object.Bits := 0;
         Object.Bit_Count := 0;
      end if;
      Outcome := Flush (Object, Writer, Destination);
      Object.Current_State :=
        (if Results.Succeeded (Outcome) then Finished else Failed);
      return Outcome;
   end Finish;
end Giflib.Internal.LZW_Encoder_Writer;
