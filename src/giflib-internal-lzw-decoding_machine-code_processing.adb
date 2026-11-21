with Giflib.Internal.Diagnostics;
with Giflib.Internal.LZW_Decoder_Reader;
with Giflib.Internal.LZW_Work;

package body Giflib.Internal.LZW.Decoding_Machine.Code_Processing is
   procedure Emit_Interlaced
     (Output : in out Streams.Byte_Array;
      Layout : Interlacing.Traversal_Layout;
      State : in out Decoder_State;
      Value : Byte)
   is
   begin
      Output (Output'First + State.Output_Target_Position) := Value;
      State.Output_Position := State.Output_Position + 1;
      if State.Output_Column + 1 < Layout.Width then
         State.Output_Column := State.Output_Column + 1;
         State.Output_Target_Position := State.Output_Target_Position + 1;
      else
         State.Output_Column := 0;
         State.Output_Stream_Row := State.Output_Stream_Row + 1;
         if State.Output_Stream_Row < Layout.Height then
            State.Output_Target_Position :=
              Interlacing.Row_For_Ordinal
                (Layout.Height, State.Output_Stream_Row) * Layout.Width;
         end if;
      end if;
   end Emit_Interlaced;
   pragma Inline_Always (Emit_Interlaced);

   procedure Reset_Dictionary
     (Context : in out Workspace;
      State : in out Decoder_State;
      Maximum_Index : Byte) is
   begin
      State.Next_Free_Code := State.First_New_Code;
      State.Code_Width := State.Minimum + 1;
      State.Have_Old_Code := False;
      LZW_Decoder_Dictionary.Reset
        (Context.Dictionary,
         LZW_Decoder_Dictionary.Code_Index (State.First_New_Code),
         Maximum_Index);
   end Reset_Dictionary;

   procedure Initialize
     (Context : in out Workspace;
      State : in out Decoder_State;
      Minimum_Code_Size : Byte;
      Maximum_Index : Byte)
   is
      Initial : LZW_Arithmetic.Initial_Code_State;
   begin
      State.Minimum := LZW_Arithmetic.Minimum_Code_Size (Minimum_Code_Size);
      Initial := LZW_Arithmetic.Initialize (State.Minimum);
      State.Clear_Code := Initial.Clear_Code;
      State.End_Code := Initial.End_Code;
      State.First_New_Code := Initial.First_Free_Code;
      Reset_Dictionary (Context, State, Maximum_Index);
   end Initialize;

   function Failure
     (Object : Streams.Source'Class;
      Output_Length : Natural;
      Frame : Frame_Ordinal;
      State : in out Decoder_State;
      Code : Errors.Error_Code;
      Value : LZW_Arithmetic.Code_Value := 0) return Process_Status is
   begin
      State.Last_Error := Errors.Make
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
             others => <>)));
      return Process_Failed;
   end Failure;

   function Invalid_Index
     (Object : Streams.Source'Class;
      Parameters : Decode_Parameters;
      State : in out Decoder_State;
      Value : Byte) return Process_Status is
   begin
      State.Last_Error := Errors.Make
        (Errors.Palette_Index_Out_Of_Range,
         Diagnostics.At_Source
           (Object,
            (Block => Image_Data_Block,
             Frame => Errors.Frame_At (Parameters.Frame),
             Expected => Byte_Count (Parameters.Maximum_Index),
             Actual => Byte_Count (Value), others => <>)));
      return Process_Failed;
   end Invalid_Index;

   function Decode_Sequence
     (Context : in out Workspace;
      Object : in out Streams.Source'Class;
      Output : out Streams.Byte_Array;
      Parameters : Decode_Parameters;
      State : in out Decoder_State;
      Code : LZW_Arithmetic.Code_Value) return Process_Status
   is
      Incoming_Code : constant LZW_Arithmetic.Code_Value := Code;
      Current : LZW_Arithmetic.Code_Value;
      Stack_Count : LZW_Arithmetic.Stack_Count := 0;
      Traversal_Work : Byte_Count := 0;
   begin
      if Code = State.Next_Free_Code then
         if not LZW_Arithmetic.Can_Push (Stack_Count) then
            return Failure
              (Object, Output'Length, Parameters.Frame, State,
               Errors.LZW_Invalid_Code, Incoming_Code);
         end if;
         if State.First_Character > Parameters.Maximum_Index then
            return Invalid_Index
              (Object, Parameters, State, State.First_Character);
         end if;
         LZW_Decoder_Dictionary.Set_Stack
           (Context.Dictionary, Stack_Count, State.First_Character);
         Stack_Count := LZW_Arithmetic.Push_Count (Stack_Count);
         Current := State.Old_Code;
      elsif Code < State.First_New_Code then
         if Code >= State.Clear_Code then
            return Failure
              (Object, Output'Length, Parameters.Frame, State,
               Errors.LZW_Invalid_Code, Incoming_Code);
         end if;
         State.First_Character := Byte (Code);
         if State.First_Character > Parameters.Maximum_Index then
            return Invalid_Index
              (Object, Parameters, State, State.First_Character);
         elsif State.Output_Position >= Output'Length then
            return Failure
              (Object, Output'Length, Parameters.Frame, State,
               Errors.LZW_Output_Size_Mismatch, Incoming_Code);
         elsif not LZW_Work.Accumulate
           (State.Work, State.Pending_Work, 1, 4_096)
         then
            State.Last_Error :=
              LZW_Work.Failure
                (Object, State.Work, Parameters.Frame).First_Error;
            return Process_Failed;
         end if;
         if Parameters.Layout.Is_Interlaced then
            Emit_Interlaced
              (Output, Parameters.Layout, State, State.First_Character);
         else
            Output (Output'First + State.Output_Position) :=
              State.First_Character;
            State.Output_Position := State.Output_Position + 1;
         end if;
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
         return Process_Continue;
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
         declare
            Definition : constant LZW_Decoder_Dictionary.Dictionary_Entry :=
              LZW_Decoder_Dictionary.Entry_At (Context.Dictionary, Current);
         begin
            LZW_Decoder_Dictionary.Set_Stack
              (Context.Dictionary, Stack_Count, Definition.Suffix);
            Current := Definition.Prefix;
         end;
         Stack_Count := LZW_Arithmetic.Push_Count (Stack_Count);
         Traversal_Work := Traversal_Work + 1;
      end loop;

      if Current >= State.Clear_Code
        or else not LZW_Arithmetic.Can_Push (Stack_Count)
      then
         return Failure
           (Object, Output'Length, Parameters.Frame, State,
            Errors.LZW_Invalid_Code, Incoming_Code);
      end if;
      State.First_Character := Byte (Current);
      if State.First_Character > Parameters.Maximum_Index then
         return Invalid_Index
           (Object, Parameters, State, State.First_Character);
      end if;
      LZW_Decoder_Dictionary.Set_Stack
        (Context.Dictionary, Stack_Count, State.First_Character);
      Stack_Count := LZW_Arithmetic.Push_Count (Stack_Count);

      if State.Output_Position > Output'Length
        or else Natural (Stack_Count) >
          Output'Length - State.Output_Position
      then
         return Failure
           (Object, Output'Length, Parameters.Frame, State,
            Errors.LZW_Output_Size_Mismatch, Incoming_Code);
      end if;
      if not LZW_Work.Accumulate
        (State.Work, State.Pending_Work,
         Traversal_Work + Byte_Count (Stack_Count), 4_096)
      then
         State.Last_Error :=
           LZW_Work.Failure
             (Object, State.Work, Parameters.Frame).First_Error;
         return Process_Failed;
      end if;
      if Parameters.Layout.Is_Interlaced then
         for I in reverse 0 .. Stack_Count - 1 loop
            Emit_Interlaced
              (Output, Parameters.Layout, State,
               LZW_Decoder_Dictionary.Stack_At (Context.Dictionary, I));
         end loop;
      else
         for I in reverse 0 .. Stack_Count - 1 loop
            Output (Output'First + State.Output_Position) :=
              LZW_Decoder_Dictionary.Stack_At (Context.Dictionary, I);
            State.Output_Position := State.Output_Position + 1;
         end loop;
      end if;

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
      return Process_Continue;
   end Decode_Sequence;

   function Process_Slow
     (Context : in out Workspace;
      Object : in out Streams.Source'Class;
      Blocks_Reader : in out Blocks.Sub_Block_Reader;
      Output : out Streams.Byte_Array;
      Parameters : Decode_Parameters;
      State : in out Decoder_State;
      Code : LZW_Arithmetic.Code_Value) return Process_Status
   is
      Outcome : Results.Result;
   begin
      if not State.Initial_Clear_Seen and then Code /= State.Clear_Code then
         State.Last_Error := Errors.Make
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
                others => <>)));
         return Process_Failed;
      elsif Code = State.Clear_Code then
         State.Initial_Clear_Seen := True;
         Reset_Dictionary (Context, State, Parameters.Maximum_Index);
         return Process_Continue;
      elsif Code = State.End_Code then
         if State.Output_Position /= Output'Length then
            return Failure
              (Object, Output'Length, Parameters.Frame, State,
               Errors.LZW_Output_Size_Mismatch, Code);
         end if;
         if not LZW_Work.Commit (State.Work, State.Pending_Work) then
            State.Last_Error :=
              LZW_Work.Failure
                (Object, State.Work, Parameters.Frame).First_Error;
            return Process_Failed;
         end if;
         Outcome := Blocks.Drain (Blocks_Reader, Object);
         if not Results.Succeeded (Outcome) then
            State.Last_Error := Outcome.First_Error;
            return Process_Failed;
         end if;
         return Process_Finished;
      elsif not State.Have_Old_Code then
         if Code >= State.Clear_Code then
            return Failure
              (Object, Output'Length, Parameters.Frame, State,
               Errors.LZW_Invalid_Code, Code);
         end if;
         State.First_Character := Byte (Code);
         if State.First_Character > Parameters.Maximum_Index then
            return Invalid_Index
              (Object, Parameters, State, State.First_Character);
         elsif State.Output_Position = Output'Length then
            return Failure
              (Object, Output'Length, Parameters.Frame, State,
               Errors.LZW_Output_Size_Mismatch, Code);
         elsif not LZW_Work.Accumulate
           (State.Work, State.Pending_Work, 1, 4_096)
         then
            State.Last_Error :=
              LZW_Work.Failure
                (Object, State.Work, Parameters.Frame).First_Error;
            return Process_Failed;
         end if;
         if Parameters.Layout.Is_Interlaced then
            Emit_Interlaced
              (Output, Parameters.Layout, State, State.First_Character);
         else
            Output (Output'First + State.Output_Position) :=
              State.First_Character;
            State.Output_Position := State.Output_Position + 1;
         end if;
         State.Old_Code := Code;
         State.Have_Old_Code := True;
         return Process_Continue;
      end if;
      return Decode_Sequence
        (Context, Object, Output, Parameters, State, Code);
   end Process_Slow;

   function Process
     (Context : in out Workspace;
      Object : in out Streams.Source'Class;
      Blocks_Reader : in out Blocks.Sub_Block_Reader;
      Output : out Streams.Byte_Array;
      Parameters : Decode_Parameters;
      State : in out Decoder_State;
      Code : LZW_Arithmetic.Code_Value) return Process_Status is
   begin
      if State.Initial_Clear_Seen
        and then State.Have_Old_Code
        and then Code /= State.Clear_Code
        and then Code /= State.End_Code
      then
         return Decode_Sequence
           (Context, Object, Output, Parameters, State, Code);
      end if;
      return Process_Slow
        (Context, Object, Blocks_Reader, Output, Parameters, State, Code);
   end Process;
end Giflib.Internal.LZW.Decoding_Machine.Code_Processing;
