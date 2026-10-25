with Giflib.Internal.Ownership.Testing;
with Giflib.Internal.Encoder_Storage.Testing;
with Giflib.Internal.Budget_Arithmetic;

package body Giflib.Encoding.Testing is
   function Allocated_Bytes (Object : Encoder) return Byte_Count is
     (Internal.Budget_Arithmetic.Charge
        (Internal.Encoder_Storage.Allocated_Bytes (Object.Resources),
         Byte_Count'Last,
         Internal.Encoder_Storage.Quantizer_Bytes (Object.Resources)).Attempted);

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
      Internal.Encoder_Storage.Testing.Inject_Quantizer_Error_After
        (Object.Resources, Successful_Allocations);
   end Inject_Quantizer_Storage_Error_After;

   procedure Disable_Failure_Injection (Object : in out Encoder) is
   begin
      Internal.Ownership.Testing.Disable (Object.Allocation_Fault);
      Internal.Encoder_Storage.Testing.Disable_Quantizer_Error
        (Object.Resources);
   end Disable_Failure_Injection;

   procedure Corrupt_Quantizer_Allocation_Budget
     (Object : in out Encoder)
   is
   begin
      Internal.Encoder_Storage.Testing.Corrupt_Quantizer_Budget
        (Object.Resources);
   end Corrupt_Quantizer_Allocation_Budget;

   procedure Corrupt_Allocation_Budget (Object : in out Encoder) is
   begin
      Internal.Encoder_Storage.Testing.Corrupt_Budget (Object.Resources);
   end Corrupt_Allocation_Budget;

   function Resources_Released (Object : Encoder) return Boolean is
     (Internal.Encoder_Storage.Is_Released (Object.Resources));

   function Quantizer_Cleanup_Succeeded (Object : Encoder) return Boolean is
     (Internal.Encoder_Storage.Testing.Quantizer_Cleanup_Succeeded
        (Object.Resources));
end Giflib.Encoding.Testing;
