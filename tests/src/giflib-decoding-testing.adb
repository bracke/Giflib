with Giflib.Internal.Ownership.Testing;
with Giflib.Internal.Decoder_Storage.Testing;

package body Giflib.Decoding.Testing is
   function Allocated_Bytes (Object : Decoder) return Byte_Count is
     (Internal.Decoder_Storage.Allocated_Bytes (Object.Resources));

   procedure Inject_Storage_Error_After
     (Object : in out Decoder;
      Successful_Allocations : Natural := 0)
   is
   begin
      Internal.Ownership.Testing.Arm
        (Object.Allocation_Fault, Successful_Allocations);
   end Inject_Storage_Error_After;

   procedure Disable_Failure_Injection (Object : in out Decoder) is
   begin
      Internal.Ownership.Testing.Disable (Object.Allocation_Fault);
   end Disable_Failure_Injection;

   procedure Corrupt_Allocation_Budget (Object : in out Decoder) is
   begin
      Internal.Decoder_Storage.Testing.Corrupt_Budget (Object.Resources);
   end Corrupt_Allocation_Budget;

   function Resources_Released (Object : Decoder) return Boolean is
     (Internal.Decoder_Storage.Is_Released (Object.Resources));
end Giflib.Decoding.Testing;
