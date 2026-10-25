with Giflib.Internal.Ownership.Testing;
with Giflib.Quantization.Testing;

package body Giflib.Internal.Encoder_Storage.Testing is
   procedure Corrupt_Budget (Object : in out Resources) is
   begin
      Ownership.Testing.Set_Used (Object.Allocation_Budget, 0);
   end Corrupt_Budget;

   procedure Inject_Quantizer_Error_After
     (Object : in out Resources;
      Successful_Allocations : Natural) is
   begin
      Quantization.Testing.Inject_Storage_Error_After
        (Object.Quantizer_Data, Successful_Allocations);
   end Inject_Quantizer_Error_After;

   procedure Disable_Quantizer_Error (Object : in out Resources) is
   begin
      Quantization.Testing.Disable_Failure_Injection (Object.Quantizer_Data);
   end Disable_Quantizer_Error;

   procedure Corrupt_Quantizer_Budget (Object : in out Resources) is
   begin
      Quantization.Testing.Corrupt_Allocation_Budget (Object.Quantizer_Data);
   end Corrupt_Quantizer_Budget;

   function Quantizer_Cleanup_Succeeded (Object : Resources) return Boolean is
     (Quantization.Cleanup_Succeeded (Object.Quantizer_Data));
end Giflib.Internal.Encoder_Storage.Testing;
