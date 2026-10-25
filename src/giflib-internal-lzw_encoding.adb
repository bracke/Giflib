with Giflib.Errors;
with Giflib.Internal.Blocks;
with Giflib.Internal.Work_Budgets;
with Giflib.Internal.Diagnostics;
with Giflib.Internal.LZW_Arithmetic;
with Giflib.Internal.LZW_Encoder_Input;
with Giflib.Internal.LZW_Encoder_Writer;

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

      Prefix : LZW_Arithmetic.Code_Value;
      Suffix : Byte;
      Found : Boolean;
      Slot : LZW_Encoder_Dictionary.Slot_Index;
      Outcome : Results.Result;
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
      Outcome := LZW_Encoder_Writer.Put
        (Codes, Writer, Object, Work, Clear_Code, Width);
      if not Results.Succeeded (Outcome) then
         return Accounted (Outcome);
      end if;
      for I in 1 .. Input'Length - 1 loop
         Suffix := LZW_Encoder_Input.Element
           (Input, I, Layout);
         if Suffix > Maximum_Index then
            return Accounted (Invalid_Index (Suffix));
         end if;
         Outcome := LZW_Encoder_Dictionary.Find
           (Context.Dictionary, Prefix, Suffix, Work, Object, Found, Slot);
         if not Results.Succeeded (Outcome) then
            return Accounted (Outcome);
         elsif Found then
            Prefix := LZW_Encoder_Dictionary.Code_At
              (Context.Dictionary, Slot);
         else
            Outcome := LZW_Encoder_Writer.Put
              (Codes, Writer, Object, Work, Prefix, Width);
            if not Results.Succeeded (Outcome) then
               return Accounted (Outcome);
            end if;
            if LZW_Arithmetic.Can_Insert (Next_Free) then
               LZW_Encoder_Dictionary.Insert
                 (Context.Dictionary, Slot, Prefix, Suffix,
                  LZW_Arithmetic.Code_Value (Next_Free));
               Next_Free := LZW_Arithmetic.After_Insert (Next_Free);
               Width := LZW_Arithmetic.Encoder_Width_After_Insert
                 (Next_Free, Width);
            else
               Outcome := LZW_Encoder_Writer.Put
                 (Codes, Writer, Object, Work, Clear_Code, Width);
               if not Results.Succeeded (Outcome) then
                  return Accounted (Outcome);
               end if;
               Outcome := Clear_Dictionary;
               if not Results.Succeeded (Outcome) then
                  return Accounted (Outcome);
               end if;
            end if;
            Prefix := LZW_Arithmetic.Code_Value (Suffix);
         end if;
      end loop;
      Outcome := LZW_Encoder_Writer.Put
        (Codes, Writer, Object, Work, Prefix, Width);
      if Results.Succeeded (Outcome) then
         Outcome := LZW_Encoder_Writer.Put
           (Codes, Writer, Object, Work, End_Code, Width);
      end if;
      if not Results.Succeeded (Outcome) then
         return Accounted (Outcome);
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
