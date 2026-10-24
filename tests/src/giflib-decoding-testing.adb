with Giflib.Internal.Ownership.Testing;

package body Giflib.Decoding.Testing is
   function Allocated_Bytes (Object : Decoder) return Byte_Count is
     (Internal.Ownership.Used (Object.Resources.Allocation_Budget));

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
end Giflib.Decoding.Testing;
