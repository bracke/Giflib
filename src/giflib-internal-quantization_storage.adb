package body Giflib.Internal.Quantization_Storage is
   procedure Release (Object : in out Resources) is
      Failed : Boolean := False;
      function Release_Histogram return Boolean is
        (Histogram_Ownership.Release
           (Object.Histogram, Object.Allocation_Budget));
      function Release_Nearest_Cache return Boolean is
        (Nearest_Cache_Ownership.Release
           (Object.Nearest_Cache, Object.Allocation_Budget));
      function Release_Error_Buffer return Boolean is
        (Error_Ownership.Release
           (Object.Errors, Object.Allocation_Budget));
      procedure Try_Histogram is new Ownership.Attempt_Release
        (Release_Histogram);
      procedure Try_Nearest_Cache is new Ownership.Attempt_Release
        (Release_Nearest_Cache);
      procedure Try_Error_Buffer is new Ownership.Attempt_Release
        (Release_Error_Buffer);
   begin
      Try_Histogram (Failed);
      Try_Nearest_Cache (Failed);
      Try_Error_Buffer (Failed);
      Object.Cleanup_Failed :=
        Object.Cleanup_Failed
        or else Failed
        or else not Ownership.Healthy (Object.Allocation_Budget);
   end Release;

   overriding procedure Finalize (Object : in out Resources) is
   begin
      Release (Object);
   end Finalize;
end Giflib.Internal.Quantization_Storage;
