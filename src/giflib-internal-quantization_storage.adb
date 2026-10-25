with Giflib.Internal.Resource_Cleanup;

package body Giflib.Internal.Quantization_Storage is
   function Histogram
     (Object : aliased in out Resources)
      return not null access Histogram_Ownership.Handle is
     (Object.Histogram_Data'Access);
   function Nearest_Cache
     (Object : aliased in out Resources)
      return not null access Nearest_Cache_Ownership.Handle
   is (Object.Nearest_Cache_Data'Access);
   function Errors
     (Object : aliased in out Resources)
      return not null access Error_Ownership.Handle is
     (Object.Error_Data'Access);
   function Budget
     (Object : aliased in out Resources)
      return not null access Ownership.Byte_Budget is
     (Object.Allocation_Budget'Access);
   function Allocated_Bytes (Object : Resources) return Byte_Count is
     (Ownership.Used (Object.Allocation_Budget));
   function Cleanup_Succeeded (Object : Resources) return Boolean is
     (not Object.Cleanup_Failed);

   procedure Release (Object : in out Resources) is
      function Release_Histogram return Boolean is
        (Histogram_Ownership.Release
           (Object.Histogram_Data, Object.Allocation_Budget));
      function Release_Nearest_Cache return Boolean is
        (Nearest_Cache_Ownership.Release
           (Object.Nearest_Cache_Data, Object.Allocation_Budget));
      function Release_Error_Buffer return Boolean is
        (Error_Ownership.Release
           (Object.Error_Data, Object.Allocation_Budget));
      procedure Release_All is new Resource_Cleanup.Release_Three
        (Release_Histogram, Release_Nearest_Cache, Release_Error_Buffer);
   begin
      Release_All (Object.Allocation_Budget, Object.Cleanup_Failed);
   end Release;

   overriding procedure Finalize (Object : in out Resources) is
   begin
      Release (Object);
   end Finalize;
end Giflib.Internal.Quantization_Storage;
