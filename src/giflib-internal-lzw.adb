with Interfaces;
with Giflib.Errors;
with Giflib.Internal.Interlacing;

package body Giflib.Internal.LZW is
   use type Interfaces.Unsigned_32;

   function Decode
     (Object : in out Streams.Source'Class;
      Blocks_Reader : in out Blocks.Sub_Block_Reader;
      Minimum_Code_Size : Byte;
      Output : out Streams.Byte_Array;
      Decoded_Count : out Byte_Count;
      Max_Work : Byte_Count;
      Frame : Frame_Ordinal := 0;
      Interlace_Width : Natural := 0;
      Interlace_Height : Natural := 0) return Results.Result
   is
      type Prefix_Table is array (Natural range 0 .. 4_095) of Natural range 0 .. 4_095;
      type Suffix_Table is array (Natural range 0 .. 4_095) of Byte;
      Prefix : Prefix_Table := [others => 0];
      Suffix : Suffix_Table := [others => 0];
      Stack : Suffix_Table := [others => 0];

      Minimum : Natural;
      Clear_Code : Natural;
      End_Code : Natural;
      First_New_Code : Natural;
      Next_Free_Code : Natural;
      Code_Width : Natural;
      Old_Code : Integer := -1;
      First_Character : Byte := 0;
      Output_Position : Natural := 0;
      Work : Byte_Count := 0;
      Code_Ordinal : Byte_Count := 0;
      Bit_Buffer : Interfaces.Unsigned_32 := 0;
      Bit_Count : Natural := 0;

      function Failure (Code : Errors.Error_Code; Value : Natural := 0) return Results.Result is
      begin
         return Results.Failure
           (Errors.Make
              (Code,
               (Source => Object.Offset,
                Block => Image_Data_Block,
                Frame => Frame,
                LZW_Code_Value => LZW_Code (Natural'Min (Value, 4_095)),
                LZW_Width => LZW_Code_Width (Code_Width),
                LZW_Code_Ordinal => Code_Ordinal,
                Has_LZW_Context => True,
                Expected => Byte_Count (Output'Length),
                Actual => Byte_Count (Output_Position),
                others => <>)));
      end Failure;

      function Charge (Amount : Byte_Count) return Results.Result is
      begin
         if Amount > Max_Work - Work then
            return Results.Failure
              (Errors.Make
                 (Errors.Limit_Exceeded,
                  (Source => Object.Offset,
                   Block => Image_Data_Block,
                   Frame => Frame,
                   Expected => Max_Work,
                   Actual => Work + Amount,
                   Limit => LZW_Work_Limit,
                   others => <>)));
         end if;
         Work := Work + Amount;
         return Results.Success;
      end Charge;

      function Next_Code (Value : out Natural) return Results.Result is
         One : Streams.Byte_Array (1 .. 1);
         Count : Byte_Count;
         At_End : Boolean;
         Outcome : Results.Result;
         Mask : Interfaces.Unsigned_32;
      begin
         Value := 0;
         while Bit_Count < Code_Width loop
            Outcome := Blocks.Read_Data (Blocks_Reader, Object, One, Count, At_End);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            elsif Count = 0 and then At_End then
               return Failure (Errors.LZW_Missing_End_Code);
            end if;
            Outcome := Charge (1);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
            Bit_Buffer := Bit_Buffer or
              Interfaces.Shift_Left (Interfaces.Unsigned_32 (One (1)), Bit_Count);
            Bit_Count := Bit_Count + 8;
         end loop;
         Mask := Interfaces.Shift_Left (Interfaces.Unsigned_32 (1), Code_Width) - 1;
         Value := Natural (Bit_Buffer and Mask);
         Bit_Buffer := Interfaces.Shift_Right (Bit_Buffer, Code_Width);
         Bit_Count := Bit_Count - Code_Width;
         Code_Ordinal := Code_Ordinal + 1;
         return Charge (1);
      end Next_Code;

      function Emit (Value : Byte) return Results.Result is
         Outcome : Results.Result;
         Target_Position : Natural := Output_Position;
      begin
         if Output_Position = Output'Length then
            return Failure (Errors.LZW_Output_Size_Mismatch);
         end if;
         if Interlace_Width > 0 then
            declare
               Stream_Row : constant Natural := Output_Position / Interlace_Width;
               Column : constant Natural := Output_Position mod Interlace_Width;
               Image_Row : constant Natural :=
                 Interlacing.Row_For_Ordinal (Interlace_Height, Stream_Row);
            begin
               if Image_Row >= Interlace_Height then
                  return Results.Failure
                    (Errors.Make
                       (Errors.Internal_Invariant_Failed,
                        (Source => Object.Offset,
                         Block => Image_Data_Block,
                         Frame => Frame,
                         others => <>)));
               end if;
               Target_Position := Image_Row * Interlace_Width + Column;
            end;
         end if;
         Outcome := Charge (1);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
         Output (Output'First + Target_Position) := Value;
         Output_Position := Output_Position + 1;
         return Results.Success;
      end Emit;

      Code : Natural;
      Incoming_Code : Natural;
      Current : Natural;
      Stack_Count : Natural;
      Outcome : Results.Result;
   begin
      Decoded_Count := 0;
      if Minimum_Code_Size < 2 or else Minimum_Code_Size > 8 then
         Code_Width := 2;
         return Failure (Errors.LZW_Invalid_Minimum_Code_Size, Natural (Minimum_Code_Size));
      end if;
      if Interlace_Width > 0
        and then (Interlace_Height = 0
                  or else Interlace_Width > Natural'Last / Interlace_Height
                  or else Interlace_Width * Interlace_Height /= Output'Length)
      then
         Code_Width := Natural (Minimum_Code_Size) + 1;
         return Results.Failure
           (Errors.Make
              (Errors.Internal_Invariant_Failed,
               (Source => Object.Offset, Block => Image_Data_Block, Frame => Frame, others => <>)));
      end if;

      Minimum := Natural (Minimum_Code_Size);
      Clear_Code := 2 ** Minimum;
      End_Code := Clear_Code + 1;
      First_New_Code := Clear_Code + 2;
      Next_Free_Code := First_New_Code;
      Code_Width := Minimum + 1;

      loop
         Outcome := Next_Code (Code);
         if not Results.Succeeded (Outcome) then
            Decoded_Count := Byte_Count (Output_Position);
            return Outcome;
         end if;

         if Code = Clear_Code then
            Next_Free_Code := First_New_Code;
            Code_Width := Minimum + 1;
            Old_Code := -1;
         elsif Code = End_Code then
            if Output_Position /= Output'Length then
               Decoded_Count := Byte_Count (Output_Position);
               return Failure (Errors.LZW_Output_Size_Mismatch, Code);
            end if;
            Outcome := Blocks.Drain (Blocks_Reader, Object);
            Decoded_Count := Byte_Count (Output_Position);
            return Outcome;
         elsif Old_Code < 0 then
            if Code >= Clear_Code then
               Decoded_Count := Byte_Count (Output_Position);
               return Failure (Errors.LZW_Invalid_Code, Code);
            end if;
            First_Character := Byte (Code);
            Outcome := Emit (First_Character);
            if not Results.Succeeded (Outcome) then
               Decoded_Count := Byte_Count (Output_Position);
               return Outcome;
            end if;
            Old_Code := Code;
         else
            Incoming_Code := Code;
            Stack_Count := 0;

            if Code = Next_Free_Code then
               Stack (Stack_Count) := First_Character;
               Stack_Count := Stack_Count + 1;
               Current := Natural (Old_Code);
            elsif Code < Next_Free_Code then
               Current := Code;
            else
               Decoded_Count := Byte_Count (Output_Position);
               return Failure (Errors.LZW_Invalid_Code, Code);
            end if;

            while Current >= First_New_Code loop
               if Current >= Next_Free_Code or else Stack_Count = Stack'Length then
                  Decoded_Count := Byte_Count (Output_Position);
                  return Failure (Errors.LZW_Invalid_Code, Incoming_Code);
               end if;
               Stack (Stack_Count) := Suffix (Current);
               Stack_Count := Stack_Count + 1;
               Current := Prefix (Current);
               Outcome := Charge (1);
               if not Results.Succeeded (Outcome) then
                  Decoded_Count := Byte_Count (Output_Position);
                  return Outcome;
               end if;
            end loop;

            if Current >= Clear_Code or else Stack_Count = Stack'Length then
               Decoded_Count := Byte_Count (Output_Position);
               return Failure (Errors.LZW_Invalid_Code, Incoming_Code);
            end if;
            First_Character := Byte (Current);
            Stack (Stack_Count) := First_Character;
            Stack_Count := Stack_Count + 1;

            for I in reverse 0 .. Stack_Count - 1 loop
               Outcome := Emit (Stack (I));
               if not Results.Succeeded (Outcome) then
                  Decoded_Count := Byte_Count (Output_Position);
                  return Outcome;
               end if;
            end loop;

            if Next_Free_Code < 4_096 then
               Prefix (Next_Free_Code) := Natural (Old_Code);
               Suffix (Next_Free_Code) := First_Character;
               Next_Free_Code := Next_Free_Code + 1;
               if Next_Free_Code = 2 ** Code_Width and then Code_Width < 12 then
                  Code_Width := Code_Width + 1;
               end if;
            end if;
            Old_Code := Incoming_Code;
         end if;
      end loop;
   end Decode;
end Giflib.Internal.LZW;
