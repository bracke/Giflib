with Interfaces;
with Giflib.Errors;
with Giflib.Internal.Work_Budgets;
with Giflib.Internal.Diagnostics;
with Giflib.Internal.Resource_Diagnostics;
with Giflib.Internal.Interlacing;
with Giflib.Internal.LZW_Bit_Arithmetic;

package body Giflib.Internal.LZW is
   function Ensure
     (Object : in out Workspace_Handle;
      Budget : aliased in out Ownership.Byte_Budget;
      Fault : in out Ownership.Fault_State;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome
   is
     (Workspace_Ownership.Ensure (Object.Owner, Budget, Fault, Maximum));

   function Release
     (Object : in out Workspace_Handle;
      Budget : aliased in out Ownership.Byte_Budget) return Boolean
   is
   begin
      return Workspace_Ownership.Release (Object.Owner, Budget);
   end Release;

   function Is_Allocated (Object : Workspace_Handle) return Boolean is
     (Workspace_Ownership.Is_Allocated (Object.Owner));

   function Decode
     (Context : in out Workspace;
      Object : in out Streams.Source'Class;
      Blocks_Reader : in out Blocks.Sub_Block_Reader;
      Minimum_Code_Size : Byte;
      Output : out Streams.Byte_Array;
      Decoded_Count : out Byte_Count;
      Max_Work : Byte_Count;
      Frame : Frame_Ordinal := 0;
      Maximum_Index : Byte := 255;
      Interlace_Width : Natural := 0;
      Interlace_Height : Natural := 0) return Results.Result
   is
      Minimum : Natural;
      Clear_Code : Natural;
      End_Code : Natural;
      First_New_Code : Natural;
      Next_Free_Code : Natural;
      Code_Width : Natural;
      Old_Code : Integer := -1;
      Initial_Clear_Seen : Boolean := False;
      First_Character : Byte := 0;
      Output_Position : Natural := 0;
      Work : Work_Budgets.Meter (Max_Work);
      Code_Ordinal : Byte_Count := 0;
      Bit_Buffer : Interfaces.Unsigned_32 := 0;
      Bit_Count : Natural := 0;
      Compressed_Buffer : Streams.Byte_Array (1 .. 255);
      Compressed_Count : Natural := 0;
      Compressed_Position : Natural := 0;

      function Failure (Code : Errors.Error_Code; Value : Natural := 0) return Results.Result is
      begin
         return Results.Failure
           (Errors.Make
              (Code,
               Diagnostics.At_Source
                 (Object,
                  (Block => Image_Data_Block,
                   Frame => Errors.Frame_At (Frame),
                   LZW => Errors.LZW_At
                     (LZW_Code (Natural'Min (Value, 4_095)),
                      LZW_Code_Width (Code_Width),
                      Code_Ordinal),
                   Expected => Byte_Count (Output'Length),
                   Actual => Byte_Count (Output_Position),
                   others => <>))));
      end Failure;

      function Charge (Amount : Byte_Count) return Results.Result is
         Accepted : Boolean;
      begin
         Work_Budgets.Try_Charge (Work, Amount, Accepted);
         if not Accepted then
            return Results.Failure
              (Errors.Make
                 (Errors.Limit_Exceeded,
                  Diagnostics.At_Source
                    (Object,
                     Resource_Diagnostics.With_Work_Limit
                       (Work,
                        LZW_Work_Limit,
                        (Block => Image_Data_Block,
                         Frame => Errors.Frame_At (Frame),
                         others => <>)))));
         end if;
         return Results.Success;
      end Charge;

      function Next_Code (Value : out Natural) return Results.Result is
         Count : Byte_Count;
         At_End : Boolean;
         Outcome : Results.Result;
         State : LZW_Bit_Arithmetic.Bit_State;
         Extracted : LZW_Bit_Arithmetic.Extracted_Code;
      begin
         Value := 0;
         while Bit_Count < Code_Width loop
            if Compressed_Position = Compressed_Count then
               Outcome := Blocks.Read_Data
                 (Blocks_Reader, Object, Compressed_Buffer, Count, At_End);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               elsif Count = 0 and then At_End then
                  return Failure (Errors.LZW_Missing_End_Code);
               end if;
               Compressed_Count := Natural (Count);
               Compressed_Position := 0;
            end if;
            Outcome := Charge (1);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
            State := LZW_Bit_Arithmetic.Append_Byte
              (Bit_Buffer,
               LZW_Bit_Arithmetic.Decoder_Append_Count (Bit_Count),
               Compressed_Buffer
                 (Compressed_Buffer'First + Compressed_Position));
            Compressed_Position := Compressed_Position + 1;
            Bit_Buffer := State.Bits;
            Bit_Count := State.Count;
         end loop;
         Extracted := LZW_Bit_Arithmetic.Extract
           (Bit_Buffer,
            LZW_Bit_Arithmetic.Bit_Count (Bit_Count),
            LZW_Bit_Arithmetic.Code_Width (Code_Width));
         Value := Natural (Extracted.Code);
         Bit_Buffer := Extracted.State.Bits;
         Bit_Count := Extracted.State.Count;
         Code_Ordinal := Code_Ordinal + 1;
         return Charge (1);
      end Next_Code;

      function Emit (Value : Byte) return Results.Result is
         Outcome : Results.Result;
         Target_Position : Natural := Output_Position;
      begin
         if Value > Maximum_Index then
            return Results.Failure
              (Errors.Make
                 (Errors.Palette_Index_Out_Of_Range,
                  Diagnostics.At_Source
                    (Object,
                     (Block => Image_Data_Block,
                      Frame => Errors.Frame_At (Frame),
                      Expected => Byte_Count (Maximum_Index),
                      Actual => Byte_Count (Value),
                      others => <>))));
         elsif Output_Position = Output'Length then
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
                        Diagnostics.At_Source
                          (Object,
                           (Block => Image_Data_Block,
                            Frame => Errors.Frame_At (Frame),
                            others => <>))));
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
      Stack_Count : LZW_Arithmetic.Stack_Count;
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
               Diagnostics.At_Source
                 (Object,
                  (Block => Image_Data_Block,
                   Frame => Errors.Frame_At (Frame),
                   others => <>))));
      end if;

      Minimum := Natural (Minimum_Code_Size);
      declare
         Initial : constant LZW_Arithmetic.Initial_Code_State :=
           LZW_Arithmetic.Initialize (LZW_Arithmetic.Minimum_Code_Size (Minimum));
      begin
         Clear_Code := Initial.Clear_Code;
         End_Code := Initial.End_Code;
         First_New_Code := Initial.First_Free_Code;
         Next_Free_Code := Initial.First_Free_Code;
         Code_Width := Initial.Width;
      end;

      loop
         Outcome := Next_Code (Code);
         if not Results.Succeeded (Outcome) then
            Decoded_Count := Byte_Count (Output_Position);
            return Outcome;
         end if;

         if not Initial_Clear_Seen and then Code /= Clear_Code then
            Decoded_Count := Byte_Count (Output_Position);
            return Results.Failure
              (Errors.Make
                 (Errors.LZW_Invalid_Code,
                  Diagnostics.At_Source
                    (Object,
                     (Block => Image_Data_Block,
                      Frame => Errors.Frame_At (Frame),
                      LZW => Errors.LZW_At
                        (LZW_Code (Code),
                         LZW_Code_Width (Code_Width),
                         Code_Ordinal),
                      Expected => Byte_Count (Clear_Code),
                      Actual => Byte_Count (Code),
                      others => <>))));
         elsif Code = Clear_Code then
            Initial_Clear_Seen := True;
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
               if not LZW_Arithmetic.Can_Push (Stack_Count) then
                  Decoded_Count := Byte_Count (Output_Position);
                  return Failure (Errors.LZW_Invalid_Code, Incoming_Code);
               end if;
               Context.Stack (Stack_Count) := First_Character;
               Stack_Count := LZW_Arithmetic.Push_Count (Stack_Count);
               Current := Natural (Old_Code);
            elsif Code < Next_Free_Code then
               Current := Code;
            else
               Decoded_Count := Byte_Count (Output_Position);
               return Failure (Errors.LZW_Invalid_Code, Code);
            end if;

            while Current >= First_New_Code loop
               if not LZW_Arithmetic.Can_Follow
                 (LZW_Arithmetic.Code_Value (Current),
                  LZW_Arithmetic.Next_Code_Value (First_New_Code),
                  LZW_Arithmetic.Next_Code_Value (Next_Free_Code),
                  Stack_Count)
               then
                  Decoded_Count := Byte_Count (Output_Position);
                  return Failure (Errors.LZW_Invalid_Code, Incoming_Code);
               end if;
               Context.Stack (Stack_Count) := Context.Suffix (Current);
               Stack_Count := LZW_Arithmetic.Push_Count (Stack_Count);
               Current := Context.Prefix (Current);
               Outcome := Charge (1);
               if not Results.Succeeded (Outcome) then
                  Decoded_Count := Byte_Count (Output_Position);
                  return Outcome;
               end if;
            end loop;

            if Current >= Clear_Code
              or else not LZW_Arithmetic.Can_Push (Stack_Count)
            then
               Decoded_Count := Byte_Count (Output_Position);
               return Failure (Errors.LZW_Invalid_Code, Incoming_Code);
            end if;
            First_Character := Byte (Current);
            Context.Stack (Stack_Count) := First_Character;
            Stack_Count := LZW_Arithmetic.Push_Count (Stack_Count);

            for I in reverse 0 .. Stack_Count - 1 loop
               Outcome := Emit (Context.Stack (I));
               if not Results.Succeeded (Outcome) then
                  Decoded_Count := Byte_Count (Output_Position);
                  return Outcome;
               end if;
            end loop;

            if LZW_Arithmetic.Can_Insert
              (LZW_Arithmetic.Next_Code_Value (Next_Free_Code))
            then
               Context.Prefix (Next_Free_Code) := Natural (Old_Code);
               Context.Suffix (Next_Free_Code) := First_Character;
               Next_Free_Code := Natural
                 (LZW_Arithmetic.After_Insert
                    (LZW_Arithmetic.Next_Code_Value (Next_Free_Code)));
               Code_Width := Natural
                 (LZW_Arithmetic.Decoder_Width_After_Insert
                    (LZW_Arithmetic.Next_Code_Value (Next_Free_Code),
                     LZW_Arithmetic.Active_Code_Width (Code_Width)));
            end if;
            Old_Code := Incoming_Code;
         end if;
      end loop;
   end Decode;

   function Decode
     (Context : in out Workspace_Handle;
      Object : in out Streams.Source'Class;
      Blocks_Reader : in out Blocks.Sub_Block_Reader;
      Minimum_Code_Size : Byte;
      Output : out Streams.Byte_Array;
      Decoded_Count : out Byte_Count;
      Max_Work : Byte_Count;
      Frame : Frame_Ordinal := 0;
      Maximum_Index : Byte := 255;
      Interlace_Width : Natural := 0;
      Interlace_Height : Natural := 0) return Results.Result
   is
   begin
      return Decode
        (Workspace_Ownership.Value (Context.Owner).all,
         Object,
         Blocks_Reader,
         Minimum_Code_Size,
         Output,
         Decoded_Count,
         Max_Work,
         Frame,
         Maximum_Index,
         Interlace_Width,
         Interlace_Height);
   end Decode;
end Giflib.Internal.LZW;
