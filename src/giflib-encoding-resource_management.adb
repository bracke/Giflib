with Giflib.Internal.Budget_Arithmetic;

package body Giflib.Encoding.Resource_Management is
   use type Internal.Ownership.Allocation_Status;
   use type Errors.Error_Code;
   package Buffers renames Internal.Owned_Buffers;

   function Release_Buffer (Resources : in out Encoder_Resources)
      return Boolean
   is
   begin
      return Buffers.Release
        (Resources.Truecolor_Pixels, Resources.Allocation_Budget);
   exception
      when others =>
         return False;
   end Release_Buffer;

   function Release_LZW (Resources : in out Encoder_Resources) return Boolean is
   begin
      return Internal.LZW_Encoding.Release
        (Resources.LZW_Workspace, Resources.Allocation_Budget);
   exception
      when others =>
         return False;
   end Release_LZW;

   function Release_Quantizer (Resources : in out Encoder_Resources)
      return Boolean
   is
   begin
      Quantization.Finalize (Resources.Quantizer);
      return Quantization.Cleanup_Succeeded (Resources.Quantizer);
   exception
      when others =>
         return False;
   end Release_Quantizer;

   procedure Release (Resources : in out Encoder_Resources) is
      Released : Boolean;
   begin
      Released := Release_Buffer (Resources);
      Released := Release_LZW (Resources) and Released;
      Released := Release_Quantizer (Resources) and Released;
      Resources.Cleanup_Failed := Resources.Cleanup_Failed or else not Released;
   end Release;

   procedure Release (Object : in out Encoder) is
   begin
      Release (Object.Resources);
   end Release;

   function Combined_Amount
     (Left : Byte_Count;
      Right : Byte_Count) return Byte_Count
   is
     (Internal.Budget_Arithmetic.Charge
        (Left, Byte_Count'Last, Right).Attempted);

   function Quantizer_Bytes (Object : Encoder) return Byte_Count is
     (Quantization.Allocated_Bytes (Object.Resources.Quantizer));

   function Outer_Maximum (Object : Encoder) return Byte_Count is
      Reserved : constant Byte_Count := Quantizer_Bytes (Object);
   begin
      return
        (if Reserved >= Object.Constraints.Max_Allocation_Bytes
         then 0
         else Object.Constraints.Max_Allocation_Bytes - Reserved);
   end Outer_Maximum;

   function Allocation_Failure
     (Object : Encoder;
      Attempted : Byte_Count) return Results.Result
   is
   begin
      return Results.Failure
        (Errors.Make
           (Errors.Limit_Exceeded,
            (Has_Destination => Output_Position (Object).Available,
             Destination => Output_Position (Object).Value,
             Expected => Object.Constraints.Max_Allocation_Bytes,
             Actual => Combined_Amount (Quantizer_Bytes (Object), Attempted),
             Limit => Allocation_Byte_Limit,
             others => <>)));
   end Allocation_Failure;

   function Allocation_Result
     (Object : Encoder;
      Allocation : Internal.Ownership.Allocation_Outcome)
      return Results.Result
   is
   begin
      if Allocation.Status = Internal.Ownership.Allocation_Owner_Error then
         return Results.Failure
           (Errors.Make
              (Errors.Internal_Invariant_Failed,
               (Has_Destination => Output_Position (Object).Available,
                Destination => Output_Position (Object).Value,
                Has_Frame => True,
                Frame => Object.Frames_Written,
                others => <>)));
      end if;
      return Allocation_Failure (Object, Allocation.Attempted);
   end Allocation_Result;

   function Ensure_Truecolor_Pixels
     (Object : in out Encoder;
      Required : Byte_Count) return Results.Result
   is
      Allocation : Internal.Ownership.Allocation_Outcome;
   begin
      if Required > Byte_Count (Natural'Last) then
         return Results.Failure (Errors.Make (Errors.Integer_Overflow));
      end if;
      Allocation := Buffers.Ensure
        (Object.Resources.Truecolor_Pixels,
         Object.Resources.Allocation_Budget,
         Object.Allocation_Fault,
         Required,
         Outer_Maximum (Object));
      if Allocation.Status /= Internal.Ownership.Allocation_Ready then
         return Allocation_Result (Object, Allocation);
      end if;
      return Results.Success;
   end Ensure_Truecolor_Pixels;

   function Ensure_LZW_Workspace
     (Object : in out Encoder) return Results.Result
   is
      Allocation : Internal.Ownership.Allocation_Outcome;
   begin
      if Internal.LZW_Encoding.Is_Allocated
        (Object.Resources.LZW_Workspace)
      then
         return Results.Success;
      end if;
      Allocation := Internal.LZW_Encoding.Ensure
        (Object.Resources.LZW_Workspace,
         Object.Resources.Allocation_Budget,
         Object.Allocation_Fault,
         Outer_Maximum (Object));
      if Allocation.Status /= Internal.Ownership.Allocation_Ready then
         return Allocation_Result (Object, Allocation);
      end if;
      return Results.Success;
   end Ensure_LZW_Workspace;

   function Quantization_Constraints
     (Object : Encoder) return Limits.Limit_Set
   is
      Result : Limits.Limit_Set := Object.Constraints;
      Reserved : constant Byte_Count :=
        Internal.Ownership.Used (Object.Resources.Allocation_Budget);
   begin
      Result.Max_Allocation_Bytes :=
        (if Reserved >= Object.Constraints.Max_Allocation_Bytes
         then 0
         else Object.Constraints.Max_Allocation_Bytes - Reserved);
      return Result;
   end Quantization_Constraints;

   function Normalize_Quantization_Error
     (Object : Encoder;
      Item : Errors.Error) return Errors.Error
   is
      Result : Errors.Error := Item;
   begin
      if Result.Code = Errors.Limit_Exceeded
        and then Result.Context.Limit = Allocation_Byte_Limit
      then
         Result.Context.Expected := Object.Constraints.Max_Allocation_Bytes;
         Result.Context.Actual := Combined_Amount
           (Internal.Ownership.Used (Object.Resources.Allocation_Budget),
            Result.Context.Actual);
      end if;
      return Result;
   end Normalize_Quantization_Error;
end Giflib.Encoding.Resource_Management;
