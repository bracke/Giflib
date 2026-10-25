with Giflib.Internal.Budget_Arithmetic;
with Giflib.Internal.Diagnostics;
with Giflib.Internal.Resource_Diagnostics;

package body Giflib.Encoding.Resource_Management is
   use type Internal.Ownership.Allocation_Status;
   use type Errors.Error_Code;

   procedure Release (Resources : in out Encoder_Resources) is
   begin
      Internal.Encoder_Storage.Release (Resources);
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
     (Internal.Encoder_Storage.Quantizer_Bytes (Object.Resources));

   function Outer_Maximum (Object : Encoder) return Byte_Count is
      Reserved : constant Byte_Count := Quantizer_Bytes (Object);
   begin
      return
        (if Reserved >= Object.Constraints.Max_Allocation_Bytes
         then 0
         else Object.Constraints.Max_Allocation_Bytes - Reserved);
   end Outer_Maximum;

   function Allocation_Result
     (Object : Encoder;
      Allocation : Internal.Ownership.Allocation_Outcome)
      return Results.Result
   is
      Context : constant Errors.Diagnostic_Context :=
        Internal.Diagnostics.At_Destination
          (Object.Output.all,
           (Frame => Errors.Frame_At (Object.Frames_Written),
            others => <>));
   begin
      return Results.Failure
        (Internal.Resource_Diagnostics.Allocation_Error
           (Allocation,
            Object.Constraints.Max_Allocation_Bytes,
            Combined_Amount (Quantizer_Bytes (Object), Allocation.Attempted),
            Context));
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
      Allocation := Internal.Encoder_Storage.Ensure_Truecolor_Pixels
        (Object.Resources,
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
      if Internal.Encoder_Storage.LZW_Allocated (Object.Resources)
      then
         return Results.Success;
      end if;
      Allocation := Internal.Encoder_Storage.Ensure_LZW
        (Object.Resources,
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
        Internal.Encoder_Storage.Allocated_Bytes (Object.Resources);
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
           (Internal.Encoder_Storage.Allocated_Bytes (Object.Resources),
            Result.Context.Actual);
      end if;
      return Result;
   end Normalize_Quantization_Error;
end Giflib.Encoding.Resource_Management;
