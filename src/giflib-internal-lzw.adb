with Giflib.Errors;
with Giflib.Internal.Work_Budgets;
with Giflib.Internal.Diagnostics;
with Giflib.Internal.LZW_Arithmetic;
with Giflib.Internal.LZW_Decoder_Output;
with Giflib.Internal.LZW_Decoder_Reader;
with Giflib.Internal.LZW_Work;

package body Giflib.Internal.LZW is
   package Workspace_Results is new Workspace_Ownership.Result_Operations
     (Results.Result);
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
      Output : out Streams.Byte_Array;
      Decoded_Count : out Byte_Count;
      Parameters : Decode_Parameters) return Results.Result
   is
      Minimum_Code_Size : constant Byte := Parameters.Minimum_Code_Size;
      Max_Work : constant Byte_Count := Parameters.Max_Work;
      Frame : constant Frame_Ordinal := Parameters.Frame;
      Maximum_Index : constant Byte := Parameters.Maximum_Index;
      Layout : constant Interlacing.Traversal_Layout := Parameters.Layout;
      Minimum : LZW_Arithmetic.Minimum_Code_Size :=
        LZW_Arithmetic.Minimum_Code_Size'First;
      Clear_Code : LZW_Arithmetic.Clear_Code_Value :=
        LZW_Arithmetic.Clear_Code_Value'First;
      End_Code : LZW_Arithmetic.Code_Value := 0;
      First_New_Code : LZW_Arithmetic.Next_Code_Value :=
        LZW_Arithmetic.Next_Code_Value'First;
      Next_Free_Code : LZW_Arithmetic.Next_Code_Value :=
        LZW_Arithmetic.Next_Code_Value'First;
      Code_Width : LZW_Arithmetic.Active_Code_Width :=
        LZW_Arithmetic.Active_Code_Width'First;
      Old_Code : LZW_Arithmetic.Code_Value := 0;
      Have_Old_Code : Boolean := False;
      Initial_Clear_Seen : Boolean := False;
      First_Character : Byte := 0;
      Output_Position : Natural := 0;
      Work : Work_Budgets.Meter (Max_Work);
      Reader : LZW_Decoder_Reader.Code_Reader;

      function Failure
        (Code : Errors.Error_Code;
         Value : LZW_Arithmetic.Code_Value := 0) return Results.Result is
      begin
         return Results.Failure
           (Errors.Make
              (Code,
               Diagnostics.At_Source
                 (Object,
                  (Block => Image_Data_Block,
                   Frame => Errors.Frame_At (Frame),
                   LZW => Errors.LZW_At
                     (LZW_Code (Value), LZW_Code_Width (Code_Width),
                      LZW_Decoder_Reader.Ordinal (Reader)),
                   Expected => Byte_Count (Output'Length),
                   Actual => Byte_Count (Output_Position),
                   others => <>))));
      end Failure;

      Code : LZW_Arithmetic.Code_Value;
      Incoming_Code : LZW_Arithmetic.Code_Value;
      Current : LZW_Arithmetic.Code_Value;
      Stack_Count : LZW_Arithmetic.Stack_Count;
      Outcome : Results.Result;
   begin
      Decoded_Count := 0;
      if Minimum_Code_Size < 2 or else Minimum_Code_Size > 8 then
         return Failure
           (Errors.LZW_Invalid_Minimum_Code_Size,
            LZW_Arithmetic.Code_Value (Minimum_Code_Size));
      end if;
      if not Interlacing.Is_Valid (Layout, Output'Length) then
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

      Minimum := LZW_Arithmetic.Minimum_Code_Size (Minimum_Code_Size);
      declare
         Initial : constant LZW_Arithmetic.Initial_Code_State :=
           LZW_Arithmetic.Initialize (Minimum);
      begin
         Clear_Code := Initial.Clear_Code;
         End_Code := Initial.End_Code;
         First_New_Code := Initial.First_Free_Code;
         Next_Free_Code := Initial.First_Free_Code;
         Code_Width := Initial.Width;
         LZW_Decoder_Dictionary.Reset
           (Context.Dictionary,
            LZW_Decoder_Dictionary.Code_Index (Initial.First_Free_Code));
      end;

      loop
         Outcome := LZW_Decoder_Reader.Next_Code
           (Reader, Object, Blocks_Reader,
            Work,
            (Code_Width => Code_Width,
             Frame => Frame,
             Output_Length => Output'Length,
             Output_Position => Output_Position),
            Code);
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
                         LZW_Decoder_Reader.Ordinal (Reader)),
                      Expected => Byte_Count (Clear_Code),
                      Actual => Byte_Count (Code),
                      others => <>))));
         elsif Code = Clear_Code then
            Initial_Clear_Seen := True;
            Next_Free_Code := First_New_Code;
            Code_Width := Minimum + 1;
            Have_Old_Code := False;
            LZW_Decoder_Dictionary.Reset
              (Context.Dictionary,
               LZW_Decoder_Dictionary.Code_Index (First_New_Code));
         elsif Code = End_Code then
            if Output_Position /= Output'Length then
               Decoded_Count := Byte_Count (Output_Position);
               return Failure (Errors.LZW_Output_Size_Mismatch, Code);
            end if;
            Outcome := Blocks.Drain (Blocks_Reader, Object);
            Decoded_Count := Byte_Count (Output_Position);
            return Outcome;
         elsif not Have_Old_Code then
            if Code >= Clear_Code then
               Decoded_Count := Byte_Count (Output_Position);
               return Failure (Errors.LZW_Invalid_Code, Code);
            end if;
            First_Character := Byte (Code);
            Outcome := LZW_Decoder_Output.Emit
              (Object, Output, Output_Position, First_Character, Work,
               (Code_Ordinal => LZW_Decoder_Reader.Ordinal (Reader),
                Maximum_Index => Maximum_Index,
                Layout => Layout,
                Code_Width => Code_Width,
                Frame => Frame));
            if not Results.Succeeded (Outcome) then
               Decoded_Count := Byte_Count (Output_Position);
               return Outcome;
            end if;
            Old_Code := Code;
            Have_Old_Code := True;
         else
            Incoming_Code := Code;
            Stack_Count := 0;

            if Code = Next_Free_Code then
               if not LZW_Arithmetic.Can_Push (Stack_Count) then
                  Decoded_Count := Byte_Count (Output_Position);
                  return Failure (Errors.LZW_Invalid_Code, Incoming_Code);
               end if;
               LZW_Decoder_Dictionary.Set_Stack
                 (Context.Dictionary, Stack_Count, First_Character);
               Stack_Count := LZW_Arithmetic.Push_Count (Stack_Count);
               Current := Old_Code;
            elsif Code < Next_Free_Code then
               Current := Code;
            else
               Decoded_Count := Byte_Count (Output_Position);
               return Failure (Errors.LZW_Invalid_Code, Code);
            end if;

            while Current >= First_New_Code loop
               if not LZW_Arithmetic.Can_Follow
                 (Current, First_New_Code, Next_Free_Code,
                  Stack_Count)
               then
                  Decoded_Count := Byte_Count (Output_Position);
                  return Failure (Errors.LZW_Invalid_Code, Incoming_Code);
               end if;
               LZW_Decoder_Dictionary.Set_Stack
                 (Context.Dictionary, Stack_Count,
                  LZW_Decoder_Dictionary.Suffix_At
                    (Context.Dictionary, Current));
               Stack_Count := LZW_Arithmetic.Push_Count (Stack_Count);
               Current := LZW_Decoder_Dictionary.Prefix_At
                 (Context.Dictionary, Current);
               Outcome := LZW_Work.Charge (Object, Work, Frame, 1);
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
            LZW_Decoder_Dictionary.Set_Stack
              (Context.Dictionary, Stack_Count, First_Character);
            Stack_Count := LZW_Arithmetic.Push_Count (Stack_Count);

            for I in reverse 0 .. Stack_Count - 1 loop
               Outcome := LZW_Decoder_Output.Emit
                 (Object, Output, Output_Position,
                  LZW_Decoder_Dictionary.Stack_At (Context.Dictionary, I),
                  Work,
                  (Code_Ordinal => LZW_Decoder_Reader.Ordinal (Reader),
                   Maximum_Index => Maximum_Index,
                   Layout => Layout,
                   Code_Width => Code_Width,
                   Frame => Frame));
               if not Results.Succeeded (Outcome) then
                  Decoded_Count := Byte_Count (Output_Position);
                  return Outcome;
               end if;
            end loop;

            if LZW_Arithmetic.Can_Insert
              (Next_Free_Code)
            then
               LZW_Decoder_Dictionary.Set_Entry
                 (Context.Dictionary,
                  LZW_Decoder_Dictionary.Code_Index (Next_Free_Code),
                  LZW_Decoder_Dictionary.Code_Index (Old_Code),
                  First_Character);
               Next_Free_Code :=
                 LZW_Arithmetic.After_Insert (Next_Free_Code);
               Code_Width := LZW_Arithmetic.Decoder_Width_After_Insert
                 (Next_Free_Code, Code_Width);
            end if;
            Old_Code := Incoming_Code;
         end if;
      end loop;
   end Decode;

   function Decode
     (Context : in out Workspace_Handle;
      Object : in out Streams.Source'Class;
      Blocks_Reader : in out Blocks.Sub_Block_Reader;
      Output : out Streams.Byte_Array;
      Decoded_Count : out Byte_Count;
      Parameters : Decode_Parameters) return Results.Result
   is
      function Run (Value : in out Workspace) return Results.Result is
      begin
         return Decode
           (Value,
            Object,
            Blocks_Reader,
            Output,
            Decoded_Count,
            Parameters);
      end Run;
   begin
      return Workspace_Results.Update (Context.Owner, Run'Access);
   end Decode;
end Giflib.Internal.LZW;
