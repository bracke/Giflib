with Giflib.Errors;
with Giflib.Internal.Block_Arithmetic;
with Giflib.Internal.Budget_Arithmetic;
with Giflib.Internal.Diagnostics;

package body Giflib.Internal.Blocks.Writer_Operations is
   function Flush_Block
     (Writer : in out Sub_Block_Writer;
      Object : in out Streams.Destination'Class) return Results.Result
   is
      Length_Data : constant Streams.Byte_Array := [1 => Byte (Writer.Used)];
      Outcome : Results.Result;
      Written : Byte_Count;
      Required : constant Byte_Count := Byte_Count (Writer.Used) + 1;
      Budget : constant Budget_Arithmetic.Charge_Result :=
        Budget_Arithmetic.Charge
          (Writer.Wire_Total, Writer.Maximum_Wire, Required);
   begin
      if Writer.Used = 0 then
         return Results.Success;
      elsif not Budget.Accepted then
         Writer.State := Write_Failed;
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               Diagnostics.At_Destination
                 (Object,
                  (Expected => Writer.Maximum_Wire,
                   Actual => Budget.Attempted,
                   Limit => Output_Byte_Limit,
                   others => <>))));
      end if;
      Outcome := Streams.Write_All (Object, Length_Data, Written);
      Writer.Wire_Total := Writer.Wire_Total + Written;
      if not Results.Succeeded (Outcome) then
         Writer.State := Write_Failed;
         return Outcome;
      end if;
      Outcome := Streams.Write_All
        (Object, Writer.Buffer (1 .. Writer.Used), Written);
      Writer.Wire_Total := Writer.Wire_Total + Written;
      Writer.Payload_Written := Writer.Payload_Written + Written;
      if not Results.Succeeded (Outcome) then
         Writer.State := Write_Failed;
         return Outcome;
      end if;
      Writer.Used := 0;
      return Results.Success;
   end Flush_Block;

   procedure Initialize
     (Writer : in out Sub_Block_Writer;
      Max_Payload_Bytes : Byte_Count;
      Max_Wire_Bytes : Byte_Count) is
   begin
      Writer.Used := 0;
      Writer.Payload_Total := 0;
      Writer.Payload_Written := 0;
      Writer.Wire_Total := 0;
      Writer.Maximum_Payload := Max_Payload_Bytes;
      Writer.Maximum_Wire := Max_Wire_Bytes;
      Writer.State := Writing;
   end Initialize;

   function Write_Data
     (Writer : in out Sub_Block_Writer;
      Object : in out Streams.Destination'Class;
      Data : Streams.Byte_Array) return Results.Result
   is
      Position : Natural := 0;
      To_Copy : Natural;
      Transfer : Block_Arithmetic.Writer_Transfer;
      Outcome : Results.Result;
      Budget : constant Budget_Arithmetic.Charge_Result :=
        Budget_Arithmetic.Charge
          (Writer.Payload_Total, Writer.Maximum_Payload,
           Byte_Count (Data'Length));
   begin
      if Writer.State /= Writing then
         return Results.Failure (Errors.Make (Errors.Invalid_State));
      elsif not Budget.Accepted then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               Diagnostics.At_Destination
                 (Object,
                  (Expected => Writer.Maximum_Payload,
                   Actual => Budget.Attempted,
                   Limit => Compressed_Byte_Limit,
                   others => <>))));
      end if;
      while Position < Data'Length loop
         Transfer := Block_Arithmetic.Plan_Write
           (Writer.Used, Position, Data'Length);
         To_Copy := Transfer.Count;
         for I in 0 .. To_Copy - 1 loop
            Writer.Buffer (Writer.Used + I + 1) :=
              Data (Data'First + Position + I);
         end loop;
         Writer.Used := Transfer.Used;
         Writer.Payload_Total := Writer.Payload_Total + Byte_Count (To_Copy);
         Position := Transfer.Position;
         if Writer.Used = 255 then
            Outcome := Flush_Block (Writer, Object);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end if;
      end loop;
      return Results.Success;
   end Write_Data;

   function Finish
     (Writer : in out Sub_Block_Writer;
      Object : in out Streams.Destination'Class) return Results.Result
   is
      Terminator : constant Streams.Byte_Array := [1 => 0];
      Outcome : Results.Result;
      Budget : Budget_Arithmetic.Charge_Result;
      Written : Byte_Count;
   begin
      if Writer.State = Write_Finished then
         return Results.Success;
      elsif Writer.State = Write_Failed then
         return Results.Failure (Errors.Make (Errors.Invalid_State));
      end if;
      Outcome := Flush_Block (Writer, Object);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      Budget := Budget_Arithmetic.Charge
        (Writer.Wire_Total, Writer.Maximum_Wire, 1);
      if not Budget.Accepted then
         Writer.State := Write_Failed;
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               Diagnostics.At_Destination
                 (Object,
                  (Expected => Writer.Maximum_Wire,
                   Actual => Budget.Attempted,
                   Limit => Output_Byte_Limit,
                   others => <>))));
      end if;
      Outcome := Streams.Write_All (Object, Terminator, Written);
      Writer.Wire_Total := Writer.Wire_Total + Written;
      Writer.State :=
        (if Results.Succeeded (Outcome)
         then Write_Finished
         else Write_Failed);
      return Outcome;
   end Finish;
end Giflib.Internal.Blocks.Writer_Operations;
