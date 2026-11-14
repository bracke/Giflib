with Giflib.Internal.Ownership.Testing;
with Giflib.Internal.Encoder_Storage.Testing;
with Giflib.Internal.Budget_Arithmetic;
with Giflib.Quantization.Testing;
with Giflib.Encoding.Wire_Output;

package body Giflib.Encoding.Testing is
   function Allocated_Bytes (Object : Encoder) return Byte_Count is
     (Internal.Budget_Arithmetic.Charge
        (Internal.Encoder_Storage.Allocated_Bytes (Object.Resources),
         Byte_Count'Last,
         Quantization.Allocated_Bytes (Object.Quantizer_Data)).Attempted);

   procedure Set_Bytes_Written
     (Object : in out Encoder;
      Value : Byte_Count)
   is
   begin
      Object.Bytes_Written := Value;
   end Set_Bytes_Written;

   function Bytes_Written (Object : Encoder) return Byte_Count is
     (Object.Bytes_Written);

   function Compressed_Bytes_Written (Object : Encoder) return Byte_Count is
     (Object.Compressed_Bytes_Written);

   function Write_Raw
     (Object : in out Encoder;
      Data : Streams.Byte_Array) return Results.Result
   is
   begin
      return Wire_Output.Write (Object, Data);
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
        (Object.Quantizer_Data, Successful_Allocations);
   end Inject_Quantizer_Storage_Error_After;

   procedure Disable_Failure_Injection (Object : in out Encoder) is
   begin
      Internal.Ownership.Testing.Disable (Object.Allocation_Fault);
      Quantization.Testing.Disable_Failure_Injection (Object.Quantizer_Data);
   end Disable_Failure_Injection;

   procedure Corrupt_Quantizer_Allocation_Budget
     (Object : in out Encoder)
   is
   begin
      Quantization.Testing.Corrupt_Allocation_Budget (Object.Quantizer_Data);
   end Corrupt_Quantizer_Allocation_Budget;

   procedure Repair_Quantizer_Allocation_Budget
     (Object : in out Encoder) is
   begin
      Quantization.Testing.Repair_Allocation_Budget (Object.Quantizer_Data);
   end Repair_Quantizer_Allocation_Budget;

   procedure Corrupt_Allocation_Budget (Object : in out Encoder) is
   begin
      Internal.Encoder_Storage.Testing.Corrupt_Budget (Object.Resources);
   end Corrupt_Allocation_Budget;

   procedure Repair_Allocation_Budget (Object : in out Encoder) is
   begin
      Internal.Encoder_Storage.Testing.Repair_Budget (Object.Resources);
   end Repair_Allocation_Budget;

   function Resources_Released (Object : Encoder) return Boolean is
     (Internal.Encoder_Storage.Is_Released (Object.Resources)
      and then Quantization.Allocated_Bytes (Object.Quantizer_Data) = 0);

   function Quantizer_Cleanup_Succeeded (Object : Encoder) return Boolean is
     (Quantization.Cleanup_Succeeded (Object.Quantizer_Data));

   function Last_Cleanup
     (Object : Encoder) return Cleanup.Cleanup_Status
   is (First_Cleanup_Status (Object));
end Giflib.Encoding.Testing;
