with Giflib.Internal.Budget_Arithmetic;
with Giflib.Internal.Bytes;
with Giflib.Internal.Diagnostics;
with Giflib.Internal.Extension_Arithmetic;
with Giflib.Internal.Loop_Extensions;
with Giflib.Internal.Metadata_Store;
with Giflib.Internal.Metadata_Arithmetic;

package body Giflib.Decoding.Extensions is
   use type Errors.Error_Code;
   use type Metadata.Extension_Kind;
   package Arithmetic renames Internal.Metadata_Arithmetic;

   function Start_Retention
     (Object : in out Decoder;
      Info : Metadata.Extension_Info)
      return Results.Result
   is
   begin
      return Internal.Metadata_Store.Start
        (Object.Resources.Metadata_Storage,
         Object.Options.Retention,
         Object.Constraints.Max_Allocation_Bytes,
         Object.Resources.Allocation_Budget,
         Object.Allocation_Fault,
         Info);
   end Start_Retention;

   function Retain_Chunk
     (Object : in out Decoder;
      Data : Streams.Byte_Array) return Results.Result
   is
   begin
      return Internal.Metadata_Store.Append
        (Object.Resources.Metadata_Storage,
         Data,
         Object.Constraints.Max_Retained_Metadata_Bytes,
         Object.Constraints.Max_Allocation_Bytes,
         Object.Resources.Allocation_Budget,
         Object.Allocation_Fault);
   end Retain_Chunk;

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
      Block : Block_Kind) return Results.Result
   is
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
      if not Results.Succeeded (Outcome) then
         return Truncated (Object, Info, Outcome);
      end if;
      return Results.Success;
   end Read_Fixed_Block;

   function Read_Sub_Blocks
     (Object : in out Decoder;
      Info : in out Metadata.Extension_Info;
      First_Data : out Streams.Byte_Array;
      First_Length : out Natural) return Results.Result
   is
      Length_Byte : Byte;
      Buffer : Streams.Byte_Array (1 .. 255);
      Outcome : Results.Result;
      Length : Natural;
      Block : constant Block_Kind := Arithmetic.Block_For (Info.Kind);
   begin
      First_Data := [others => 0];
      First_Length := 0;
      loop
         Outcome := Internal.Bytes.Read_Byte
           (Object.Input.all, Length_Byte, Block);
         if not Results.Succeeded (Outcome) then
            return Truncated (Object, Info, Outcome);
         end if;
         Length := Natural (Length_Byte);
         exit when Length = 0;
         if not Arithmetic.Can_Append
           (Info.Payload_Length,
            Object.Constraints.Max_Per_Extension_Bytes,
            Length)
         then
            return Results.Failure
              (Errors.Make
                 (Errors.Limit_Exceeded,
                  Internal.Diagnostics.At_Source
                    (Object.Input.all,
                     (Block => Block,
                      Extension_Label =>
                        Errors.Extension_Label_At (Metadata.Label_Of (Info)),
                      Expected => Object.Constraints.Max_Per_Extension_Bytes,
                      Actual => Internal.Budget_Arithmetic.Charge
                        (Info.Payload_Length,
                         Byte_Count'Last,
                         Byte_Count (Length)).Attempted,
                      Limit => Per_Extension_Byte_Limit,
                      others => <>))));
         end if;
         Outcome := Streams.Read_Exact
           (Object.Input.all, Buffer (1 .. Length));
         if not Results.Succeeded (Outcome) then
            return Truncated (Object, Info, Outcome);
         end if;
         if First_Length = 0 then
            First_Length := Length;
            First_Data (1 .. Length) := Buffer (1 .. Length);
         end if;
         Outcome := Retain_Chunk (Object, Buffer (1 .. Length));
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

   function Read_Graphic_Control
     (Object : in out Decoder;
      Info : in out Metadata.Extension_Info) return Results.Result
   is separate;

   function Read_Application
     (Object : in out Decoder;
      Info : in out Metadata.Extension_Info) return Results.Result
   is separate;

   function Read_Plain_Text
     (Object : in out Decoder;
      Info : in out Metadata.Extension_Info) return Results.Result
   is separate;

   function Read_Variable_Extension
     (Object : in out Decoder;
      Info : in out Metadata.Extension_Info) return Results.Result
   is separate;

   function Read
     (Object      : in out Decoder;
      Offset      : Source_Offset;
      Label_Value : Byte;
      Info        : out Metadata.Extension_Info) return Results.Result
   is
      Outcome : Results.Result;
   begin
      case Metadata.Kind_Of (Label_Value) is
         when Metadata.Graphic_Control_Extension =>
            Info := (Kind => Metadata.Graphic_Control_Extension,
                     Offset => Offset, Before_Frame => Object.Frames_Seen,
                     others => <>);
         when Metadata.Comment_Extension =>
            Info := (Kind => Metadata.Comment_Extension,
                     Offset => Offset, Before_Frame => Object.Frames_Seen,
                     others => <>);
         when Metadata.Plain_Text_Extension =>
            Info := (Kind => Metadata.Plain_Text_Extension,
                     Offset => Offset, Before_Frame => Object.Frames_Seen,
                     others => <>);
         when Metadata.Application_Extension =>
            Info := (Kind => Metadata.Application_Extension,
                     Offset => Offset, Before_Frame => Object.Frames_Seen,
                     others => <>);
         when Metadata.Unknown_Extension =>
            Info := (Kind => Metadata.Unknown_Extension,
                     Offset => Offset, Before_Frame => Object.Frames_Seen,
                     Label => Label_Value,
                     others => <>);
      end case;

      if Object.Extensions_Seen >= Object.Constraints.Max_Extensions then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Source_Position => Errors.Source_Position_At (Offset),
                Extension_Label => Errors.Extension_Label_At (Label_Value),
                Expected => Byte_Count (Object.Constraints.Max_Extensions),
                Actual => Byte_Count (Object.Extensions_Seen) + 1,
                Limit => Extension_Count_Limit,
                others => <>)));
      end if;
      Object.Extensions_Seen := Object.Extensions_Seen + 1;

      case Info.Kind is
         when Metadata.Graphic_Control_Extension =>
            Outcome := Read_Graphic_Control (Object, Info);
         when Metadata.Application_Extension =>
            Outcome := Read_Application (Object, Info);
         when Metadata.Plain_Text_Extension =>
            Outcome := Read_Plain_Text (Object, Info);
         when Metadata.Comment_Extension | Metadata.Unknown_Extension =>
            Outcome := Read_Variable_Extension (Object, Info);
      end case;

      if Results.Succeeded (Outcome) then
         Outcome := Internal.Metadata_Store.Finish
           (Object.Resources.Metadata_Storage, Info);
      end if;
      return Outcome;
   end Read;
end Giflib.Decoding.Extensions;
