with Giflib.Internal.Ownership.Testing;

package body Giflib.Internal.Quantization_Storage.Testing is
   procedure Corrupt_Budget (Object : in out Resources) is
   begin
      Ownership.Testing.Set_Used (Object.Allocation_Budget, 0);
   end Corrupt_Budget;

   procedure Repair_Budget (Object : in out Resources) is
   begin
      Ownership.Testing.Set_Used (Object.Allocation_Budget, 0);
   end Repair_Budget;
end Giflib.Internal.Quantization_Storage.Testing;
