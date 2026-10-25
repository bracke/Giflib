with Giflib.Internal.Ownership.Testing;
with Giflib.Internal.Quantization_Storage.Testing;

package body Giflib.Quantization.Testing is
   procedure Inject_Storage_Error_After
     (Context : in out Workspace;
      Successful_Allocations : Natural := 0)
   is
   begin
      Internal.Ownership.Testing.Arm
        (Context.Allocation_Fault, Successful_Allocations);
   end Inject_Storage_Error_After;

   procedure Disable_Failure_Injection (Context : in out Workspace) is
   begin
      Internal.Ownership.Testing.Disable (Context.Allocation_Fault);
   end Disable_Failure_Injection;

   procedure Corrupt_Allocation_Budget (Context : in out Workspace) is
   begin
      Internal.Quantization_Storage.Testing.Corrupt_Budget
        (Context.Resources);
   end Corrupt_Allocation_Budget;
end Giflib.Quantization.Testing;
