with Giflib.Internal.Blocks;
with Giflib.Internal.Budget_Arithmetic;
with Giflib.Internal.Bytes;
with Giflib.Internal.Diagnostics;
with Giflib.Internal.Metadata_Arithmetic;
with Giflib.Decoding.Extensions.Retention;

package body Giflib.Decoding.Extensions.Transport is
   use type Errors.Error_Code;
   package Arithmetic renames Internal.Metadata_Arithmetic;

   function Truncated
     (Object : Decoder;
      Info : Metadata.Extension_Info;
      Outcome : Results.Result) return Results.Result
   is
      Block : constant Block_Kind := Arithmetic.Block_For (Info.Kind);
      Item : Errors.Error := Outcome.First_Error;
   begin
      if Outcome.First_Error.Code = Errors.Source_Unexpected_End then
         Item.Code := Errors.Truncated_Block;
         Item.Context.Block := Block;
         Item.Context.Extension_Label :=
           Errors.Extension_Label_At (Metadata.Label_Of (Info));
         Item.Context := Internal.Diagnostics.At_Source
           (Object.Input.all, Item.Context);
         return Results.Failure (Item);
      end if;
      Item.Context.Block := Block;
      Item.Context.Extension_Label :=
        Errors.Extension_Label_At (Metadata.Label_Of (Info));
      return Results.Failure (Item);
   end Truncated;

   function Check_Fixed_Payload
     (Object : Decoder;
      Info : Metadata.Extension_Info;
      Length : Natural;
      Block : Block_Kind) return Results.Result is
   begin
      if Byte_Count (Length) > Object.Constraints.Max_Per_Extension_Bytes then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               Internal.Diagnostics.At_Source
                 (Object.Input.all,
                  (Block => Block,
                   Extension_Label =>
                     Errors.Extension_Label_At (Metadata.Label_Of (Info)),
                   Expected => Object.Constraints.Max_Per_Extension_Bytes,
                   Actual => Byte_Count (Length),
                   Limit => Per_Extension_Byte_Limit,
                   others => <>))));
      end if;
      return Results.Success;
   end Check_Fixed_Payload;

   function Read_Fixed_Block
     (Object : in out Decoder;
      Info : Metadata.Extension_Info;
      Data : out Streams.Byte_Array) return Results.Result
   is
      Size_Byte : Byte;
      Outcome : Results.Result;
      Block : constant Block_Kind := Arithmetic.Block_For (Info.Kind);
   begin
      Outcome := Internal.Bytes.Read_Byte (Object.Input.all, Size_Byte, Block);
      if not Results.Succeeded (Outcome) then
         return Truncated (Object, Info, Outcome);
      elsif Natural (Size_Byte) /= Data'Length then
         declare
            Prior : constant Streams.Source_Position_Result :=
              Streams.Position (Object.Input.all, 1);
         begin
            return Results.Failure
              (Errors.Make
                 (Errors.Invalid_Extension,
                  (Source_Position =>
                     Internal.Diagnostics.With_Source
                       ((others => <>), Prior).Source_Position,
                   Block => Block,
                   Extension_Label =>
                     Errors.Extension_Label_At (Metadata.Label_Of (Info)),
                   Expected => Byte_Count (Data'Length),
                   Actual => Byte_Count (Size_Byte),
                   others => <>)));
         end;
      end if;
      Outcome := Check_Fixed_Payload (Object, Info, Data'Length, Block);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      Outcome := Streams.Read_Exact (Object.Input.all, Data);
      return
        (if Results.Succeeded (Outcome)
         then Results.Success
         else Truncated (Object, Info, Outcome));
   end Read_Fixed_Block;

   function Read_Sub_Blocks
     (Object : in out Decoder;
      Info : in out Metadata.Extension_Info;
      First_Data : out Streams.Byte_Array;
      First_Length : out Natural) return Results.Result
   is
      Reader : Internal.Blocks.Sub_Block_Reader;
      Buffer : Streams.Byte_Array (1 .. 255);
      Outcome : Results.Result;
      Length : Natural;
      Count : Byte_Count;
      At_End : Boolean := False;
      Block : constant Block_Kind := Arithmetic.Block_For (Info.Kind);
      Initial_Length : constant Byte_Count := Info.Payload_Length;
   begin
      First_Data := [others => 0];
      First_Length := 0;
      Internal.Blocks.Initialize
        (Reader,
         Object.Constraints.Max_Per_Extension_Bytes - Initial_Length,
         Per_Extension_Byte_Limit,
         Block);
      while not At_End loop
         Outcome := Internal.Blocks.Read_Data
           (Reader, Object.Input.all, Buffer, Count, At_End);
         if not Results.Succeeded (Outcome) then
            if Outcome.First_Error.Code = Errors.Limit_Exceeded
              and then Outcome.First_Error.Context.Limit =
                Per_Extension_Byte_Limit
            then
               declare
                  Item : Errors.Error := Outcome.First_Error;
               begin
                  Item.Context.Expected :=
                    Object.Constraints.Max_Per_Extension_Bytes;
                  Item.Context.Actual := Internal.Budget_Arithmetic.Charge
                    (Initial_Length, Byte_Count'Last,
                     Item.Context.Actual).Attempted;
                  Outcome := Results.Failure (Item);
               end;
            end if;
            return Truncated (Object, Info, Outcome);
         end if;
         exit when At_End;
         if Count = 0 or else Count > Byte_Count (Buffer'Length) then
            return Results.Failure
              (Errors.Make (Errors.Internal_Invariant_Failed));
         end if;
         Length := Natural (Count);
         if First_Length = 0 then
            First_Length := Length;
            First_Data (1 .. Length) := Buffer (1 .. Length);
         end if;
         Outcome := Retention.Append (Object, Buffer (1 .. Length));
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
         Info.Payload_Length := Arithmetic.Appended_Length
           (Info.Payload_Length,
            Object.Constraints.Max_Per_Extension_Bytes,
            Length);
         if not Arithmetic.Can_Increment (Info.Sub_Block_Count) then
            return Results.Failure
              (Errors.Make
                 (Errors.Integer_Overflow,
                  Internal.Diagnostics.At_Source
                    (Object.Input.all,
                     (Block => Block,
                      Extension_Label =>
                        Errors.Extension_Label_At (Metadata.Label_Of (Info)),
                      others => <>))));
         end if;
         Info.Sub_Block_Count := Arithmetic.Increment (Info.Sub_Block_Count);
      end loop;
      return Results.Success;
   end Read_Sub_Blocks;
end Giflib.Decoding.Extensions.Transport;
