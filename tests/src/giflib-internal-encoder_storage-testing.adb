with Giflib.Internal.Ownership.Testing;

package body Giflib.Internal.Encoder_Storage.Testing is
   procedure Corrupt_Budget (Object : in out Resources) is
   begin
      Ownership.Testing.Set_Used (Object.Allocation_Budget, 0);
   end Corrupt_Budget;
end Giflib.Internal.Encoder_Storage.Testing;
