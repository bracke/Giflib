with Giflib.Errors;
with Giflib.Internal.Block_Arithmetic;
with Giflib.Internal.Budget_Arithmetic;
with Giflib.Internal.Bytes;
with Giflib.Internal.Diagnostics;

package body Giflib.Internal.Blocks.Reader_Operations is
   use type Errors.Error_Code;

   procedure Initialize
     (Reader : in out Sub_Block_Reader;
      Max_Bytes : Byte_Count;
      Limit : Limit_Kind;
      Block : Block_Kind) is
   begin
      Reader.Remaining := 0;
      Reader.Total := 0;
      Reader.Maximum := Max_Bytes;
      Reader.Applied_Limit := Limit;
      Reader.Owner_Block := Block;
      Reader.State := Reading;
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
      End_Of_Data := Reader.State = Read_Finished;
      if Reader.State = Read_Failed then
         return Results.Failure (Errors.Make (Errors.Invalid_State));
      elsif Reader.State = Read_Finished or else Buffer'Length = 0 then
         return Results.Success;
      end if;

      if Reader.Remaining = 0 then
         Outcome := Bytes.Read_Byte (Object, Length_Byte, Reader.Owner_Block);
         if not Results.Succeeded (Outcome) then
            Reader.State := Read_Failed;
            return As_Block_Error (Outcome, Reader, Object);
         end if;
         if Length_Byte = 0 then
            Reader.State := Read_Finished;
            End_Of_Data := True;
            return Results.Success;
         end if;
         Budget := Budget_Arithmetic.Charge
           (Reader.Total, Reader.Maximum, Byte_Count (Length_Byte));
         if not Budget.Accepted then
            Reader.State := Read_Failed;
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
         Reader.Remaining := Natural (Length_Byte);
      end if;

      Transfer := Block_Arithmetic.Plan_Read
        (Reader.Remaining, Buffer'Length);
      To_Read := Transfer.Count;
      Outcome := Streams.Read_Exact
        (Object, Buffer (Buffer'First .. Buffer'First + To_Read - 1));
      if not Results.Succeeded (Outcome) then
         Reader.State := Read_Failed;
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
end Giflib.Internal.Blocks.Reader_Operations;
