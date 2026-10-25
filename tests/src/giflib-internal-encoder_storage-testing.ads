package Giflib.Internal.Encoder_Storage.Testing is
   procedure Corrupt_Budget (Object : in out Resources);
   procedure Inject_Quantizer_Error_After
     (Object : in out Resources;
      Successful_Allocations : Natural);
   procedure Disable_Quantizer_Error (Object : in out Resources);
   procedure Corrupt_Quantizer_Budget (Object : in out Resources);
   function Quantizer_Cleanup_Succeeded (Object : Resources) return Boolean;
end Giflib.Internal.Encoder_Storage.Testing;
