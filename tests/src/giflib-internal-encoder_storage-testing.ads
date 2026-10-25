with Giflib.Internal.Cleanup;

package Giflib.Internal.Encoder_Storage.Testing is
   procedure Corrupt_Budget (Object : in out Resources);
   function Last_Cleanup (Object : Resources) return Cleanup.Cleanup_Status;
end Giflib.Internal.Encoder_Storage.Testing;
