with Giflib.Errors;
with Giflib.Internal.Blocks;
with Giflib.Internal.Work_Budgets;
with Giflib.Internal.Diagnostics;
with Giflib.Internal.LZW_Arithmetic;
with Giflib.Internal.LZW_Encoder_Input;
with Giflib.Internal.LZW_Encoder_Writer;
with Giflib.Internal.LZW_Work;

package body Giflib.Internal.LZW_Encoding is
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
      Budget : aliased in out Ownership.Byte_Budget)
      return Cleanup.Cleanup_Outcome
   is
   begin
      return Workspace_Ownership.Release (Object.Owner, Budget);
   end Release;

   function Is_Allocated (Object : Workspace_Handle) return Boolean is
     (Workspace_Ownership.Is_Allocated (Object.Owner));

   function Encode
     (Context : in out Workspace;
      Object : in out Streams.Destination'Class;
      Input : Streams.Byte_Array;
      Parameters : Encode_Parameters;
      Statistics : out Encode_Statistics) return Results.Result
   is
      Minimum_Code_Size : constant Byte := Parameters.Minimum_Code_Size;
      Max_Work : constant Byte_Count := Parameters.Max_Work;
      Max_Compressed_Bytes : constant Byte_Count :=
        Parameters.Max_Compressed_Bytes;
      Max_Wire_Bytes : constant Byte_Count := Parameters.Max_Wire_Bytes;
      Maximum_Index : constant Byte := Parameters.Maximum_Index;
      Layout : constant Interlacing.Traversal_Layout := Parameters.Layout;
      Compressed_Bytes : Byte_Count renames Statistics.Compressed_Bytes;
      Wire_Bytes : Byte_Count renames Statistics.Wire_Bytes;
      Writer : Blocks.Sub_Block_Writer;
      Codes : LZW_Encoder_Writer.Code_Writer;
      Width : LZW_Arithmetic.Active_Code_Width;
      Clear_Code : LZW_Arithmetic.Clear_Code_Value;
      End_Code : LZW_Arithmetic.Code_Value;
      Next_Free : LZW_Arithmetic.Next_Code_Value;
      Work : Work_Budgets.Meter (Max_Work);
      Pending_Work : Byte_Count := 0;
      Work_Batch_Size : constant Byte_Count := 4_096;

      type Code_Put_Status is
        (Code_Put_Succeeded, Code_Put_Work_Failed, Code_Put_Writer_Failed);

      function Commit_Pending_Work return Boolean is
      begin
         if Pending_Work = 0 then
            return True;
         elsif not LZW_Work.Try_Charge (Work, Pending_Work) then
            return False;
         end if;
         Pending_Work := 0;
         return True;
      end Commit_Pending_Work;

      function Clear_Dictionary return Results.Result is
         Outcome : constant Results.Result :=
           LZW_Encoder_Dictionary.Clear (Context.Dictionary, Work, Object);
      begin
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
         Next_Free := LZW_Arithmetic.Next_Code_Value (Clear_Code + 2);
         Width := LZW_Arithmetic.Active_Code_Width
           (Natural (Minimum_Code_Size) + 1);
         return Results.Success;
      end Clear_Dictionary;

      function Invalid_Index (Value : Byte) return Results.Result is
      begin
         return Results.Failure
           (Errors.Make
              (Errors.Palette_Index_Out_Of_Range,
               Diagnostics.At_Destination
                 (Object,
                  (Expected => Byte_Count (Maximum_Index),
                   Actual => Byte_Count (Value),
                   others => <>))));
      end Invalid_Index;

      function Accounted (Outcome : Results.Result) return Results.Result is
      begin
         Compressed_Bytes := Blocks.Total_Payload_Written (Writer);
         Wire_Bytes := Blocks.Total_Wire_Bytes (Writer);
         return Outcome;
      end Accounted;

      function Put_Code
        (Code : LZW_Arithmetic.Code_Value) return Code_Put_Status is
      begin
         Pending_Work := Pending_Work + 1;
         if (Pending_Work >= Work_Batch_Size
             or else not Work_Budgets.Can_Charge (Work, Pending_Work))
           and then not Commit_Pending_Work
         then
            return Code_Put_Work_Failed;
         end if;
         return
           (if LZW_Encoder_Writer.Put_Validated
              (Codes, Writer, Object, Code, Width)
            then Code_Put_Succeeded
            else Code_Put_Writer_Failed);
      end Put_Code;

      Prefix : LZW_Arithmetic.Code_Value;
      Suffix : Byte;
      Outcome : Results.Result;

      function Failed_Result
        (Status : Code_Put_Status) return Results.Result is
        (case Status is
           when Code_Put_Work_Failed => LZW_Work.Failure (Object, Work),
           when Code_Put_Writer_Failed =>
             Results.Failure (LZW_Encoder_Writer.Failure_Error (Codes)),
           when Code_Put_Succeeded => raise Program_Error)
        with Pre => Status /= Code_Put_Succeeded;
   begin
      Compressed_Bytes := 0;
      Wire_Bytes := 0;
      if Minimum_Code_Size < 2 or else Minimum_Code_Size > 8 then
         return Results.Failure (Errors.Make (Errors.LZW_Invalid_Minimum_Code_Size));
      elsif Input'Length = 0 then
         return Results.Failure (Errors.Make (Errors.Invalid_Dimensions));
      elsif not Interlacing.Is_Valid (Layout, Input'Length) then
         return Results.Failure (Errors.Make (Errors.Internal_Invariant_Failed));
      end if;
      declare
         Initial : constant LZW_Arithmetic.Initial_Code_State :=
           LZW_Arithmetic.Initialize
             (LZW_Arithmetic.Minimum_Code_Size (Natural (Minimum_Code_Size)));
      begin
         Clear_Code := Initial.Clear_Code;
         End_Code := Initial.End_Code;
      end;
      Blocks.Initialize (Writer, Max_Compressed_Bytes, Max_Wire_Bytes);
      Outcome := Clear_Dictionary;
      if not Results.Succeeded (Outcome) then
         return Accounted (Outcome);
      end if;
      Prefix := LZW_Arithmetic.Code_Value
        (LZW_Encoder_Input.Element
           (Input, 0, Layout));
      if Byte (Prefix) > Maximum_Index then
         return Accounted (Invalid_Index (Byte (Prefix)));
      end if;
      declare
         Status : constant Code_Put_Status :=
           Put_Code (Clear_Code);
      begin
         if Status /= Code_Put_Succeeded then
            return Accounted (Failed_Result (Status));
         end if;
      end;
      for I in 1 .. Input'Length - 1 loop
         Suffix := LZW_Encoder_Input.Element
           (Input, I, Layout);
         if Suffix > Maximum_Index then
            return Accounted (Invalid_Index (Suffix));
         end if;
         declare
            Probe_Work : Byte_Count;
            Slot : LZW_Encoder_Dictionary.Slot_Index;
            Lookup : constant LZW_Encoder_Dictionary.Validated_Lookup_Kind :=
              LZW_Encoder_Dictionary.Find_Validated
                (Context.Dictionary, Prefix, Suffix, Slot, Probe_Work);
         begin
            Pending_Work := Pending_Work + Probe_Work;
            if (Pending_Work >= Work_Batch_Size
                or else not Work_Budgets.Can_Charge (Work, Pending_Work))
              and then not Commit_Pending_Work
            then
               return Accounted (LZW_Work.Failure (Object, Work));
            end if;
            case Lookup is
               when LZW_Encoder_Dictionary.Validated_Failure =>
                  return Accounted
                    (Results.Failure (Errors.Internal_Invariant_Failed));
               when LZW_Encoder_Dictionary.Validated_Hit =>
                  Prefix := LZW_Encoder_Dictionary.Code_At
                    (Context.Dictionary, Slot);
               when LZW_Encoder_Dictionary.Validated_Miss =>
                  declare
                     Status : constant Code_Put_Status :=
                       Put_Code (Prefix);
                  begin
                     if Status /= Code_Put_Succeeded then
                        return Accounted (Failed_Result (Status));
                     end if;
                  end;
                  if LZW_Arithmetic.Can_Insert (Next_Free) then
                     LZW_Encoder_Dictionary.Insert
                       (Context.Dictionary, Slot, Prefix, Suffix,
                        LZW_Arithmetic.Code_Value (Next_Free));
                     Next_Free := LZW_Arithmetic.After_Insert (Next_Free);
                     Width := LZW_Arithmetic.Encoder_Width_After_Insert
                       (Next_Free, Width);
                  else
                     declare
                        Status : constant Code_Put_Status :=
                          Put_Code (Clear_Code);
                     begin
                        if Status /= Code_Put_Succeeded then
                           return Accounted (Failed_Result (Status));
                        end if;
                     end;
                     Outcome := Clear_Dictionary;
                     if not Results.Succeeded (Outcome) then
                        return Accounted (Outcome);
                     end if;
                  end if;
                  Prefix := LZW_Arithmetic.Code_Value (Suffix);
            end case;
         end;
      end loop;
      declare
         Status : constant Code_Put_Status :=
           Put_Code (Prefix);
      begin
         if Status /= Code_Put_Succeeded then
            return Accounted (Failed_Result (Status));
         end if;
      end;
      declare
         Status : constant Code_Put_Status :=
           Put_Code (End_Code);
      begin
         if Status /= Code_Put_Succeeded then
            return Accounted (Failed_Result (Status));
         end if;
      end;
      if not Commit_Pending_Work then
         return Accounted (LZW_Work.Failure (Object, Work));
      end if;
      Outcome := LZW_Encoder_Writer.Finish
        (Codes, Writer, Object);
      if not Results.Succeeded (Outcome) then
         return Accounted (Outcome);
      end if;
      Outcome := Blocks.Finish (Writer, Object);
      return Accounted (Outcome);
   end Encode;

   function Encode
     (Context : in out Workspace_Handle;
      Object : in out Streams.Destination'Class;
      Input : Streams.Byte_Array;
      Parameters : Encode_Parameters;
      Statistics : out Encode_Statistics) return Results.Result
   is
      function Run (Value : in out Workspace) return Results.Result is
      begin
         return Encode
           (Value,
            Object,
            Input,
            Parameters,
            Statistics);
      end Run;
   begin
      return Workspace_Results.Update (Context.Owner, Run'Access);
   end Encode;

end Giflib.Internal.LZW_Encoding;
