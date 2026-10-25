with Giflib.Errors;
with Giflib.Internal.Block_Arithmetic;
with Giflib.Internal.Budget_Arithmetic;
with Giflib.Internal.Bytes;
with Giflib.Internal.Diagnostics;

package body Giflib.Internal.Blocks is
   use type Errors.Error_Code;

   procedure Initialize
     (Reader : in out Sub_Block_Reader;
      Max_Bytes : Byte_Count;
      Limit : Limit_Kind;
      Block : Block_Kind)
   is
   begin
      Reader.Remaining := 0;
      Reader.Total := 0;
      Reader.Maximum := Max_Bytes;
      Reader.Applied_Limit := Limit;
      Reader.Owner_Block := Block;
      Reader.At_End := False;
   end Initialize;

   function As_Block_Error
     (Outcome : Results.Result;
      Reader : Sub_Block_Reader;
      Object : Streams.Source'Class) return Results.Result
   is
      Item : Errors.Error := Outcome.First_Error;
   begin
      if Outcome.First_Error.Code = Errors.Source_Unexpected_End then
         Item.Code := Errors.Truncated_Block;
         Item.Context.Block := Reader.Owner_Block;
         Item.Context := Diagnostics.At_Source (Object, Item.Context);
         return Results.Failure (Item);
      end if;
      return Outcome;
   end As_Block_Error;

   function Read_Data
     (Reader : in out Sub_Block_Reader;
      Object : in out Streams.Source'Class;
      Buffer : out Streams.Byte_Array;
      Count : out Byte_Count;
      End_Of_Data : out Boolean) return Results.Result
   is
      Outcome : Results.Result;
      Length_Byte : Byte;
      To_Read : Natural;
      Transfer : Block_Arithmetic.Reader_Transfer;
      Budget : Budget_Arithmetic.Charge_Result;
   begin
      Count := 0;
      End_Of_Data := Reader.At_End;
      if Reader.At_End or else Buffer'Length = 0 then
         return Results.Success;
      end if;

      if Reader.Remaining = 0 then
         Outcome := Bytes.Read_Byte (Object, Length_Byte, Reader.Owner_Block);
         if not Results.Succeeded (Outcome) then
            return As_Block_Error (Outcome, Reader, Object);
         end if;
         if Length_Byte = 0 then
            Reader.At_End := True;
            End_Of_Data := True;
            return Results.Success;
         end if;
         Reader.Remaining := Natural (Length_Byte);
         Budget := Budget_Arithmetic.Charge
           (Reader.Total, Reader.Maximum, Byte_Count (Reader.Remaining));
         if not Budget.Accepted then
            return Results.Failure
              (Errors.Make
                 (Errors.Limit_Exceeded,
                  Diagnostics.At_Source
                    (Object,
                     (Block => Reader.Owner_Block,
                      Expected => Reader.Maximum,
                      Actual => Budget.Attempted,
                      Limit => Reader.Applied_Limit,
                      others => <>))));
         end if;
      end if;

      Transfer := Block_Arithmetic.Plan_Read (Reader.Remaining, Buffer'Length);
      To_Read := Transfer.Count;
      Outcome := Streams.Read_Exact (Object, Buffer (Buffer'First .. Buffer'First + To_Read - 1));
      if not Results.Succeeded (Outcome) then
         return As_Block_Error (Outcome, Reader, Object);
      end if;
      Reader.Remaining := Transfer.Remaining;
      Reader.Total := Reader.Total + Byte_Count (To_Read);
      Count := Byte_Count (To_Read);
      return Results.Success;
   end Read_Data;

   function Drain
     (Reader : in out Sub_Block_Reader;
      Object : in out Streams.Source'Class) return Results.Result
   is
      Scratch : Streams.Byte_Array (1 .. 255);
      Count : Byte_Count;
      At_End : Boolean := False;
      Outcome : Results.Result;
   begin
      while not At_End loop
         Outcome := Read_Data (Reader, Object, Scratch, Count, At_End);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end loop;
      return Results.Success;
   end Drain;

   function Total_Bytes (Reader : Sub_Block_Reader) return Byte_Count is
   begin
      return Reader.Total;
   end Total_Bytes;

   function Finished (Reader : Sub_Block_Reader) return Boolean is
   begin
      return Reader.At_End;
   end Finished;

   function Flush_Block
     (Writer : in out Sub_Block_Writer;
      Object : in out Streams.Destination'Class) return Results.Result
   is
      Length_Data : constant Streams.Byte_Array := [1 => Byte (Writer.Used)];
      Outcome : Results.Result;
      Written : Byte_Count;
      Required : constant Byte_Count := Byte_Count (Writer.Used) + 1;
      Budget : constant Budget_Arithmetic.Charge_Result :=
        Budget_Arithmetic.Charge (Writer.Wire_Total, Writer.Maximum_Wire, Required);
   begin
      if Writer.Used = 0 then
         return Results.Success;
      elsif not Budget.Accepted then
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
      if Results.Succeeded (Outcome) then
         Outcome := Streams.Write_All
           (Object, Writer.Buffer (1 .. Writer.Used), Written);
         Writer.Wire_Total := Writer.Wire_Total + Written;
         Writer.Payload_Written := Writer.Payload_Written + Written;
      end if;
      if Results.Succeeded (Outcome) then
         Writer.Used := 0;
      end if;
      return Outcome;
   end Flush_Block;

   procedure Initialize
     (Writer : in out Sub_Block_Writer;
      Max_Payload_Bytes : Byte_Count;
      Max_Wire_Bytes : Byte_Count)
   is
   begin
      Writer.Used := 0;
      Writer.Payload_Total := 0;
      Writer.Payload_Written := 0;
      Writer.Wire_Total := 0;
      Writer.Maximum_Payload := Max_Payload_Bytes;
      Writer.Maximum_Wire := Max_Wire_Bytes;
      Writer.Is_Finished := False;
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
          (Writer.Payload_Total, Writer.Maximum_Payload, Byte_Count (Data'Length));
   begin
      if Writer.Is_Finished then
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
            Writer.Buffer (Writer.Used + I + 1) := Data (Data'First + Position + I);
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
      if Writer.Is_Finished then
         return Results.Success;
      end if;
      Outcome := Flush_Block (Writer, Object);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      Budget := Budget_Arithmetic.Charge
        (Writer.Wire_Total, Writer.Maximum_Wire, 1);
      if not Budget.Accepted then
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
      if Results.Succeeded (Outcome) then
         Writer.Is_Finished := True;
      end if;
      return Outcome;
   end Finish;

   function Total_Payload_Bytes (Writer : Sub_Block_Writer) return Byte_Count is
   begin
      return Writer.Payload_Total;
   end Total_Payload_Bytes;

   function Total_Payload_Written
     (Writer : Sub_Block_Writer) return Byte_Count
   is
   begin
      return Writer.Payload_Written;
   end Total_Payload_Written;

   function Total_Wire_Bytes (Writer : Sub_Block_Writer) return Byte_Count is
   begin
      return Writer.Wire_Total;
   end Total_Wire_Bytes;
end Giflib.Internal.Blocks;
