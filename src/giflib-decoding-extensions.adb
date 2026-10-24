with Giflib.Internal.Budget_Arithmetic;
with Giflib.Internal.Bytes;
with Giflib.Internal.Extension_Arithmetic;
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
         return Results.Failure
           (Errors.Make
              (Errors.Truncated_Block,
               (Has_Source => Input_Position (Object).Available,
                Source => Input_Position (Object).Value,
                Block => Block,
                Extension_Label => Info.Label,
                others => <>)));
      end if;
      Item.Context.Block := Block;
      Item.Context.Extension_Label := Info.Label;
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
               (Has_Source => Input_Position (Object).Available,
                Source => Input_Position (Object).Value,
                Block => Block,
                Extension_Label => Info.Label,
                Expected => Object.Constraints.Max_Per_Extension_Bytes,
                Actual => Byte_Count (Length),
                Limit => Per_Extension_Byte_Limit,
                others => <>)));
      end if;
      return Results.Success;
   end Check_Fixed_Payload;

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
                  (Has_Source => Input_Position (Object).Available,
                   Source => Input_Position (Object).Value,
                   Block => Block,
                   Extension_Label => Info.Label,
                   Expected => Object.Constraints.Max_Per_Extension_Bytes,
                   Actual => Internal.Budget_Arithmetic.Charge
                     (Info.Payload_Length,
                      Byte_Count'Last,
                      Byte_Count (Length)).Attempted,
                   Limit => Per_Extension_Byte_Limit,
                   others => <>)));
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
                  (Has_Source => Input_Position (Object).Available,
                   Source => Input_Position (Object).Value,
                   Block => Block,
                   Extension_Label => Info.Label,
                   others => <>)));
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
      Info :=
        (Label => Label_Value,
         Offset => Offset,
         Before_Frame => Object.Frames_Seen,
         others => <>);
      Info.Kind := Arithmetic.Classify (Label_Value);

      if Object.Extensions_Seen >= Object.Constraints.Max_Extensions then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Has_Source => True, Source => Offset,
                Extension_Label => Label_Value,
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
         Internal.Metadata_Store.Finish
           (Object.Resources.Metadata_Storage, Info);
      end if;
      return Outcome;
   end Read;
end Giflib.Decoding.Extensions;
