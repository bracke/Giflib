with Giflib.Internal.Ownership.Testing;
with Giflib.Internal.Budget_Arithmetic;
with Giflib.Quantization.Testing;

package body Giflib.Encoding.Testing is
   function Allocated_Bytes (Object : Encoder) return Byte_Count is
     (Internal.Budget_Arithmetic.Charge
        (Internal.Ownership.Used (Object.Resources.Allocation_Budget),
         Byte_Count'Last,
         Quantization.Allocated_Bytes (Object.Resources.Quantizer)).Attempted);

   procedure Set_Bytes_Written
     (Object : in out Encoder;
      Value : Byte_Count)
   is
   begin
      Object.Bytes_Written := Value;
   end Set_Bytes_Written;

   function Write_Raw
     (Object : in out Encoder;
      Data : Streams.Byte_Array) return Results.Result
   is
   begin
      return Encoding.Write_Raw (Object, Data);
   end Write_Raw;

   procedure Inject_Storage_Error_After
     (Object : in out Encoder;
      Successful_Allocations : Natural := 0)
   is
   begin
      Internal.Ownership.Testing.Arm
        (Object.Allocation_Fault, Successful_Allocations);
   end Inject_Storage_Error_After;

   procedure Inject_Quantizer_Storage_Error_After
     (Object : in out Encoder;
      Successful_Allocations : Natural := 0)
   is
   begin
      Quantization.Testing.Inject_Storage_Error_After
        (Object.Resources.Quantizer, Successful_Allocations);
   end Inject_Quantizer_Storage_Error_After;

   procedure Disable_Failure_Injection (Object : in out Encoder) is
   begin
      Internal.Ownership.Testing.Disable (Object.Allocation_Fault);
      Quantization.Testing.Disable_Failure_Injection
        (Object.Resources.Quantizer);
   end Disable_Failure_Injection;

   procedure Corrupt_Quantizer_Allocation_Budget
     (Object : in out Encoder)
   is
   begin
      Quantization.Testing.Corrupt_Allocation_Budget
        (Object.Resources.Quantizer);
   end Corrupt_Quantizer_Allocation_Budget;

   function Quantizer_Cleanup_Succeeded (Object : Encoder) return Boolean is
     (Quantization.Cleanup_Succeeded (Object.Resources.Quantizer));
end Giflib.Encoding.Testing;
