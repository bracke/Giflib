with Giflib.Errors;
with Giflib.Internal.Block_Arithmetic;
with Giflib.Internal.Budget_Arithmetic;
with Giflib.Internal.Diagnostics;

package body Giflib.Internal.Blocks.Writer_Operations is
   function Flush_Block
     (Writer : in out Sub_Block_Writer;
      Object : in out Streams.Destination'Class) return Write_Status
   is
      Wire_Data : Streams.Byte_Array (1 .. 256);
      Outcome : Results.Result;
      Written : Byte_Count;
      Required : constant Byte_Count := Byte_Count (Writer.Used) + 1;
      Budget : constant Budget_Arithmetic.Charge_Result :=
        Budget_Arithmetic.Charge
          (Writer.Wire_Total, Writer.Maximum_Wire, Required);
   begin
      if Writer.Used = 0 then
         return Write_Ready;
      elsif not Budget.Accepted then
         Writer.State := Write_Failed;
         Writer.Last_Error := Errors.Make
           (Errors.Limit_Exceeded,
            Diagnostics.At_Destination
              (Object,
               (Expected => Writer.Maximum_Wire,
                Actual => Budget.Attempted,
                Limit => Output_Byte_Limit,
                others => <>)));
         return Write_Failed;
      end if;
      Wire_Data (1) := Byte (Writer.Used);
      Wire_Data (2 .. Writer.Used + 1) := Writer.Buffer (1 .. Writer.Used);
      Outcome := Streams.Write_All
        (Object, Wire_Data (1 .. Writer.Used + 1), Written);
      Writer.Wire_Total := Writer.Wire_Total + Written;
      if Written > 1 then
         Writer.Payload_Written := Writer.Payload_Written + Written - 1;
      end if;
      if not Results.Succeeded (Outcome) then
         Writer.State := Write_Failed;
         Writer.Last_Error := Outcome.First_Error;
         return Write_Failed;
      end if;
      Writer.Used := 0;
      return Write_Ready;
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
      Writer.Last_Error := Errors.No_Error_Value;
   end Initialize;

   function Write_Data
     (Writer : in out Sub_Block_Writer;
      Object : in out Streams.Destination'Class;
      Data : Streams.Byte_Array) return Results.Result
   is
      Status : constant Write_Status :=
        Write_Data_Validated (Writer, Object, Data);
   begin
      return
        (if Status = Write_Ready
         then Results.Success
         else Results.Failure (Writer.Last_Error));
   end Write_Data;

   function Write_Data_Validated
     (Writer : in out Sub_Block_Writer;
      Object : in out Streams.Destination'Class;
      Data : Streams.Byte_Array) return Write_Status
   is
      Position : Natural := 0;
      To_Copy : Natural;
      Transfer : Block_Arithmetic.Writer_Transfer;
      Budget : constant Budget_Arithmetic.Charge_Result :=
        Budget_Arithmetic.Charge
          (Writer.Payload_Total, Writer.Maximum_Payload,
           Byte_Count (Data'Length));
   begin
      if Writer.State /= Writing then
         Writer.Last_Error := Errors.Make (Errors.Invalid_State);
         return Write_Failed;
      elsif not Budget.Accepted then
         Writer.Last_Error := Errors.Make
           (Errors.Limit_Exceeded,
            Diagnostics.At_Destination
              (Object,
               (Expected => Writer.Maximum_Payload,
                Actual => Budget.Attempted,
                Limit => Compressed_Byte_Limit,
                others => <>)));
         return Write_Failed;
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
            if Flush_Block (Writer, Object) /= Write_Ready then
               return Write_Failed;
            end if;
         end if;
      end loop;
      return Write_Ready;
   end Write_Data_Validated;

   function Put_Byte_Validated
     (Writer : in out Sub_Block_Writer;
      Object : in out Streams.Destination'Class;
      Value : Byte) return Write_Status
   is
      Attempted : Byte_Count;
   begin
      if Writer.State /= Writing then
         Writer.Last_Error := Errors.Make (Errors.Invalid_State);
         return Write_Failed;
      elsif Writer.Payload_Total = Writer.Maximum_Payload then
         Attempted :=
           (if Writer.Payload_Total = Byte_Count'Last
            then Byte_Count'Last
            else Writer.Payload_Total + 1);
         Writer.Last_Error := Errors.Make
           (Errors.Limit_Exceeded,
            Diagnostics.At_Destination
              (Object,
               (Expected => Writer.Maximum_Payload,
                Actual => Attempted,
                Limit => Compressed_Byte_Limit,
                others => <>)));
         return Write_Failed;
      end if;
      Writer.Used := Writer.Used + 1;
      Writer.Buffer (Writer.Used) := Value;
      Writer.Payload_Total := Writer.Payload_Total + 1;
      return
        (if Writer.Used < Writer.Buffer'Length
         then Write_Ready
         else Flush_Block (Writer, Object));
   end Put_Byte_Validated;

   function Put_Two_Bytes_Validated
     (Writer : in out Sub_Block_Writer;
      Object : in out Streams.Destination'Class;
      First, Second : Byte) return Write_Status
   is
      Status : Write_Status;
   begin
      if Writer.State = Writing
        and then Writer.Maximum_Payload >= Writer.Payload_Total
        and then Writer.Maximum_Payload - Writer.Payload_Total >= 2
        and then Writer.Used <= 253
      then
         Writer.Buffer (Writer.Used + 1) := First;
         Writer.Buffer (Writer.Used + 2) := Second;
         Writer.Used := Writer.Used + 2;
         Writer.Payload_Total := Writer.Payload_Total + 2;
         return
           (if Writer.Used < Writer.Buffer'Length
            then Write_Ready else Flush_Block (Writer, Object));
      end if;

      Status := Put_Byte_Validated (Writer, Object, First);
      if Status /= Write_Ready then
         return Status;
      end if;
      return Put_Byte_Validated (Writer, Object, Second);
   end Put_Two_Bytes_Validated;

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
      if Flush_Block (Writer, Object) /= Write_Ready then
         return Results.Failure (Writer.Last_Error);
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
