with Giflib.Internal.Diagnostics;
with Giflib.Internal.LZW_Decoder_Output;
with Giflib.Internal.LZW_Decoder_Reader;
with Giflib.Internal.LZW_Work;

package body Giflib.Internal.LZW.Decoding_Machine.Code_Processing is
   procedure Reset_Dictionary
     (Context : in out Workspace;
      State : in out Decoder_State) is
   begin
      State.Next_Free_Code := State.First_New_Code;
      State.Code_Width := State.Minimum + 1;
      State.Have_Old_Code := False;
      LZW_Decoder_Dictionary.Reset
        (Context.Dictionary,
         LZW_Decoder_Dictionary.Code_Index (State.First_New_Code));
   end Reset_Dictionary;

   procedure Initialize
     (Context : in out Workspace;
      State : in out Decoder_State;
      Minimum_Code_Size : Byte)
   is
      Initial : LZW_Arithmetic.Initial_Code_State;
   begin
      State.Minimum := LZW_Arithmetic.Minimum_Code_Size (Minimum_Code_Size);
      Initial := LZW_Arithmetic.Initialize (State.Minimum);
      State.Clear_Code := Initial.Clear_Code;
      State.End_Code := Initial.End_Code;
      State.First_New_Code := Initial.First_Free_Code;
      Reset_Dictionary (Context, State);
   end Initialize;

   function Failure
     (Object : Streams.Source'Class;
      Output_Length : Natural;
      Frame : Frame_Ordinal;
      State : Decoder_State;
      Code : Errors.Error_Code;
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
                  (LZW_Code (Value), LZW_Code_Width (State.Code_Width),
                   LZW_Decoder_Reader.Ordinal (State.Reader)),
                Expected => Byte_Count (Output_Length),
                Actual => Byte_Count (State.Output_Position),
                others => <>))));
   end Failure;

   function Decode_Sequence
     (Context : in out Workspace;
      Object : in out Streams.Source'Class;
      Output : out Streams.Byte_Array;
      Parameters : Decode_Parameters;
      State : in out Decoder_State;
      Code : LZW_Arithmetic.Code_Value) return Results.Result
   is
      Incoming_Code : constant LZW_Arithmetic.Code_Value := Code;
      Current : LZW_Arithmetic.Code_Value;
      Stack_Count : LZW_Arithmetic.Stack_Count := 0;
      Outcome : Results.Result;
   begin
      if Code = State.Next_Free_Code then
         if not LZW_Arithmetic.Can_Push (Stack_Count) then
            return Failure
              (Object, Output'Length, Parameters.Frame, State,
               Errors.LZW_Invalid_Code, Incoming_Code);
         end if;
         LZW_Decoder_Dictionary.Set_Stack
           (Context.Dictionary, Stack_Count, State.First_Character);
         Stack_Count := LZW_Arithmetic.Push_Count (Stack_Count);
         Current := State.Old_Code;
      elsif Code < State.Next_Free_Code then
         Current := Code;
      else
         return Failure
           (Object, Output'Length, Parameters.Frame, State,
            Errors.LZW_Invalid_Code, Code);
      end if;

      while Current >= State.First_New_Code loop
         if not LZW_Arithmetic.Can_Follow
           (Current, State.First_New_Code, State.Next_Free_Code, Stack_Count)
         then
            return Failure
              (Object, Output'Length, Parameters.Frame, State,
               Errors.LZW_Invalid_Code, Incoming_Code);
         end if;
         LZW_Decoder_Dictionary.Set_Stack
           (Context.Dictionary, Stack_Count,
            LZW_Decoder_Dictionary.Suffix_At
              (Context.Dictionary, Current));
         Stack_Count := LZW_Arithmetic.Push_Count (Stack_Count);
         Current := LZW_Decoder_Dictionary.Prefix_At
           (Context.Dictionary, Current);
         Outcome := LZW_Work.Charge
           (Object, State.Work, Parameters.Frame, 1);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end loop;

      if Current >= State.Clear_Code
        or else not LZW_Arithmetic.Can_Push (Stack_Count)
      then
         return Failure
           (Object, Output'Length, Parameters.Frame, State,
            Errors.LZW_Invalid_Code, Incoming_Code);
      end if;
      State.First_Character := Byte (Current);
      LZW_Decoder_Dictionary.Set_Stack
        (Context.Dictionary, Stack_Count, State.First_Character);
      Stack_Count := LZW_Arithmetic.Push_Count (Stack_Count);

      for I in reverse 0 .. Stack_Count - 1 loop
         Outcome := LZW_Decoder_Output.Emit
           (Object, Output, State.Output_Position,
            LZW_Decoder_Dictionary.Stack_At (Context.Dictionary, I),
            State.Work,
            (Code_Ordinal => LZW_Decoder_Reader.Ordinal (State.Reader),
             Maximum_Index => Parameters.Maximum_Index,
             Layout => Parameters.Layout,
             Code_Width => State.Code_Width,
             Frame => Parameters.Frame));
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end loop;

      if LZW_Arithmetic.Can_Insert (State.Next_Free_Code) then
         LZW_Decoder_Dictionary.Set_Entry
           (Context.Dictionary,
            LZW_Decoder_Dictionary.Code_Index (State.Next_Free_Code),
            LZW_Decoder_Dictionary.Code_Index (State.Old_Code),
            State.First_Character);
         State.Next_Free_Code :=
           LZW_Arithmetic.After_Insert (State.Next_Free_Code);
         State.Code_Width := LZW_Arithmetic.Decoder_Width_After_Insert
           (State.Next_Free_Code, State.Code_Width);
      end if;
      State.Old_Code := Incoming_Code;
      return Results.Success;
   end Decode_Sequence;

   function Process
     (Context : in out Workspace;
      Object : in out Streams.Source'Class;
      Blocks_Reader : in out Blocks.Sub_Block_Reader;
      Output : out Streams.Byte_Array;
      Parameters : Decode_Parameters;
      State : in out Decoder_State;
      Code : LZW_Arithmetic.Code_Value;
      Finished : out Boolean) return Results.Result
   is
      Outcome : Results.Result;
   begin
      Finished := False;
      if not State.Initial_Clear_Seen and then Code /= State.Clear_Code then
         return Results.Failure
           (Errors.Make
              (Errors.LZW_Invalid_Code,
               Diagnostics.At_Source
                 (Object,
                  (Block => Image_Data_Block,
                   Frame => Errors.Frame_At (Parameters.Frame),
                   LZW => Errors.LZW_At
                     (LZW_Code (Code), LZW_Code_Width (State.Code_Width),
                      LZW_Decoder_Reader.Ordinal (State.Reader)),
                   Expected => Byte_Count (State.Clear_Code),
                   Actual => Byte_Count (Code),
                   others => <>))));
      elsif Code = State.Clear_Code then
         State.Initial_Clear_Seen := True;
         Reset_Dictionary (Context, State);
         return Results.Success;
      elsif Code = State.End_Code then
         if State.Output_Position /= Output'Length then
            return Failure
              (Object, Output'Length, Parameters.Frame, State,
               Errors.LZW_Output_Size_Mismatch, Code);
         end if;
         Outcome := Blocks.Drain (Blocks_Reader, Object);
         Finished := Results.Succeeded (Outcome);
         return Outcome;
      elsif not State.Have_Old_Code then
         if Code >= State.Clear_Code then
            return Failure
              (Object, Output'Length, Parameters.Frame, State,
               Errors.LZW_Invalid_Code, Code);
         end if;
         State.First_Character := Byte (Code);
         Outcome := LZW_Decoder_Output.Emit
           (Object, Output, State.Output_Position, State.First_Character,
            State.Work,
            (Code_Ordinal => LZW_Decoder_Reader.Ordinal (State.Reader),
             Maximum_Index => Parameters.Maximum_Index,
             Layout => Parameters.Layout,
             Code_Width => State.Code_Width,
             Frame => Parameters.Frame));
         if Results.Succeeded (Outcome) then
            State.Old_Code := Code;
            State.Have_Old_Code := True;
         end if;
         return Outcome;
      end if;
      return Decode_Sequence
        (Context, Object, Output, Parameters, State, Code);
   end Process;
end Giflib.Internal.LZW.Decoding_Machine.Code_Processing;
