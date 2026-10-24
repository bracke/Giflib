with Interfaces;
with Giflib.Errors;
with Giflib.Internal.Blocks;
with Giflib.Internal.Budget_Arithmetic;
with Giflib.Internal.Interlacing;
with Giflib.Internal.LZW_Bit_Arithmetic;

package body Giflib.Internal.LZW_Encoding is
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

   function Encode
     (Context : in out Workspace;
      Object : in out Streams.Destination'Class;
      Input : Streams.Byte_Array;
      Minimum_Code_Size : Byte;
      Max_Work : Byte_Count;
      Max_Compressed_Bytes : Byte_Count;
      Max_Wire_Bytes : Byte_Count;
      Compressed_Bytes : out Byte_Count;
      Maximum_Index : Byte := 255;
      Interlace_Width : Natural := 0;
      Interlace_Height : Natural := 0) return Results.Result
   is
      Writer : Blocks.Sub_Block_Writer;
      Bits : Interfaces.Unsigned_32 := 0;
      Bit_Count : Natural := 0;
      Width : Natural;
      Clear_Code : Natural;
      End_Code : Natural;
      Next_Free : Natural;
      Work : Byte_Count := 0;
      Pending : Streams.Byte_Array (1 .. 255);
      Pending_Count : Natural range 0 .. 255 := 0;

      function Charge (Amount : Byte_Count) return Results.Result is
         Budget : constant Budget_Arithmetic.Charge_Result :=
           Budget_Arithmetic.Charge (Work, Max_Work, Amount);
      begin
         if not Budget.Accepted then
            return Results.Failure
              (Errors.Make
                 (Errors.Limit_Exceeded,
                  (Has_Destination => Streams.Position (Object).Available,
                   Destination => Streams.Position (Object).Value,
                   Expected => Max_Work,
                   Actual => Budget.Attempted,
                   Limit => LZW_Work_Limit,
                   others => <>)));
         end if;
         Work := Budget.Total;
         return Results.Success;
      end Charge;

      function Flush_Pending return Results.Result is
         Outcome : Results.Result;
      begin
         if Pending_Count = 0 then
            return Results.Success;
         end if;
         Outcome := Blocks.Write_Data
           (Writer, Object, Pending (1 .. Pending_Count));
         if Results.Succeeded (Outcome) then
            Pending_Count := 0;
         end if;
         return Outcome;
      end Flush_Pending;

      function Put_Byte (Value : Byte) return Results.Result is
         Outcome : Results.Result;
      begin
         Pending_Count := Pending_Count + 1;
         Pending (Pending_Count) := Value;
         if Pending_Count = Pending'Length then
            Outcome := Flush_Pending;
            return Outcome;
         end if;
         return Results.Success;
      end Put_Byte;

      function Put_Code (Code : Natural) return Results.Result is
         Outcome : Results.Result;
         State : LZW_Bit_Arithmetic.Bit_State;
      begin
         Outcome := Charge (1);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
         State := LZW_Bit_Arithmetic.Append_Code
           (Bits,
            LZW_Bit_Arithmetic.Encoder_Append_Count (Bit_Count),
            LZW_Bit_Arithmetic.Code_Value (Code),
            LZW_Bit_Arithmetic.Code_Width (Width));
         Bits := State.Bits;
         Bit_Count := State.Count;
         while Bit_Count >= 8 loop
            Outcome := Put_Byte (LZW_Bit_Arithmetic.First_Byte (Bits));
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
            State := LZW_Bit_Arithmetic.Drop_Byte
              (Bits, LZW_Bit_Arithmetic.Bit_Count (Bit_Count));
            Bits := State.Bits;
            Bit_Count := State.Count;
         end loop;
         return Results.Success;
      end Put_Code;

      procedure Clear_Dictionary is
      begin
         Context.Used := [others => False];
         Next_Free := Clear_Code + 2;
         Width := Natural (Minimum_Code_Size) + 1;
      end Clear_Dictionary;

      function Find
        (Prefix : Natural;
         Suffix : Byte;
         Found : out Boolean;
         Slot : out Natural) return Results.Result
      is
         Position : Natural := Natural
           (LZW_Arithmetic.Hash_Start
              (LZW_Arithmetic.Code_Value (Prefix), Suffix));
         Outcome : Results.Result;
      begin
         loop
            Outcome := Charge (1);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
            if not Context.Used (Position) then
               Found := False;
               Slot := Position;
               return Results.Success;
            elsif Context.Prefix_Key (Position) = Prefix
              and then Context.Suffix_Key (Position) = Suffix
            then
               Found := True;
               Slot := Position;
               return Results.Success;
            end if;
            Position := Natural
              (LZW_Arithmetic.Next_Hash_Slot
                 (LZW_Arithmetic.Hash_Slot (Position)));
         end loop;
      end Find;

      function Input_At (Ordinal : Natural) return Byte is
         Position : Natural := Ordinal;
      begin
         if Interlace_Width > 0 then
            Position :=
              Interlacing.Row_For_Ordinal (Interlace_Height, Ordinal / Interlace_Width)
              * Interlace_Width + Ordinal mod Interlace_Width;
         end if;
         return Input (Input'First + Position);
      end Input_At;

      function Invalid_Index (Value : Byte) return Results.Result is
      begin
         return Results.Failure
           (Errors.Make
              (Errors.Palette_Index_Out_Of_Range,
               (Has_Destination => Streams.Position (Object).Available,
                Destination => Streams.Position (Object).Value,
                Expected => Byte_Count (Maximum_Index),
                Actual => Byte_Count (Value),
                others => <>)));
      end Invalid_Index;

      Prefix : Natural;
      Suffix : Byte;
      Found : Boolean;
      Slot : Natural;
      Outcome : Results.Result;
   begin
      Compressed_Bytes := 0;
      if Minimum_Code_Size < 2 or else Minimum_Code_Size > 8 then
         return Results.Failure (Errors.Make (Errors.LZW_Invalid_Minimum_Code_Size));
      elsif Input'Length = 0 then
         return Results.Failure (Errors.Make (Errors.Invalid_Dimensions));
      elsif Interlace_Width > 0
        and then (Interlace_Height = 0
                  or else Interlace_Width > Natural'Last / Interlace_Height
                  or else Interlace_Width * Interlace_Height /= Input'Length)
      then
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
      Clear_Dictionary;
      Prefix := Natural (Input_At (0));
      if Byte (Prefix) > Maximum_Index then
         return Invalid_Index (Byte (Prefix));
      end if;
      Outcome := Put_Code (Clear_Code);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      for I in 1 .. Input'Length - 1 loop
         Suffix := Input_At (I);
         if Suffix > Maximum_Index then
            return Invalid_Index (Suffix);
         end if;
         Outcome := Find (Prefix, Suffix, Found, Slot);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         elsif Found then
            Prefix := Context.Code_Value (Slot);
         else
            Outcome := Put_Code (Prefix);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
            if LZW_Arithmetic.Can_Insert
              (LZW_Arithmetic.Next_Code_Value (Next_Free))
            then
               Context.Used (Slot) := True;
               Context.Prefix_Key (Slot) := Prefix;
               Context.Suffix_Key (Slot) := Suffix;
               Context.Code_Value (Slot) := Next_Free;
               Next_Free := Natural
                 (LZW_Arithmetic.After_Insert
                    (LZW_Arithmetic.Next_Code_Value (Next_Free)));
               Width := Natural
                 (LZW_Arithmetic.Encoder_Width_After_Insert
                    (LZW_Arithmetic.Next_Code_Value (Next_Free),
                     LZW_Arithmetic.Active_Code_Width (Width)));
            else
               Outcome := Put_Code (Clear_Code);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
               Outcome := Charge (Hash_Size);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
               Clear_Dictionary;
            end if;
            Prefix := Natural (Suffix);
         end if;
      end loop;
      Outcome := Put_Code (Prefix);
      if Results.Succeeded (Outcome) then
         Outcome := Put_Code (End_Code);
      end if;
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      if Bit_Count > 0 then
         Outcome := Put_Byte (LZW_Bit_Arithmetic.First_Byte (Bits));
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;
      Outcome := Flush_Pending;
      if not Results.Succeeded (Outcome) then
         Compressed_Bytes := Blocks.Total_Payload_Bytes (Writer);
         return Outcome;
      end if;
      Outcome := Blocks.Finish (Writer, Object);
      Compressed_Bytes := Blocks.Total_Payload_Bytes (Writer);
      return Outcome;
   end Encode;

   function Encode
     (Context : in out Workspace_Handle;
      Object : in out Streams.Destination'Class;
      Input : Streams.Byte_Array;
      Minimum_Code_Size : Byte;
      Max_Work : Byte_Count;
      Max_Compressed_Bytes : Byte_Count;
      Max_Wire_Bytes : Byte_Count;
      Compressed_Bytes : out Byte_Count;
      Maximum_Index : Byte := 255;
      Interlace_Width : Natural := 0;
      Interlace_Height : Natural := 0) return Results.Result
   is
   begin
      return Encode
        (Workspace_Ownership.Value (Context.Owner).all,
         Object,
         Input,
         Minimum_Code_Size,
         Max_Work,
         Max_Compressed_Bytes,
         Max_Wire_Bytes,
         Compressed_Bytes,
         Maximum_Index,
         Interlace_Width,
         Interlace_Height);
   end Encode;
end Giflib.Internal.LZW_Encoding;
