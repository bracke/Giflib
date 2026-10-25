with Giflib.Internal.Resource_Cleanup;

package body Giflib.Internal.Quantization_Storage is
   function Ensure_Histogram
     (Object : in out Resources;
      Fault : in out Ownership.Fault_State;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome
   is (Histogram_Ownership.Ensure
         (Object.Histogram_Data, Object.Allocation_Budget, Fault, Maximum));
   function Ensure_Nearest_Cache
     (Object : in out Resources;
      Fault : in out Ownership.Fault_State;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome
   is (Nearest_Cache_Ownership.Ensure
         (Object.Nearest_Cache_Data, Object.Allocation_Budget,
          Fault, Maximum));
   function Ensure_Errors
     (Object : in out Resources;
      Fault : in out Ownership.Fault_State;
      Last : Natural;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome
   is (Error_Ownership.Ensure
         (Object.Error_Data, Object.Allocation_Budget, Fault,
          First => 0, Last => Last, Maximum => Maximum));
   function Histogram_Allocated (Object : Resources) return Boolean is
     (Histogram_Ownership.Is_Allocated (Object.Histogram_Data));
   function Nearest_Cache_Allocated (Object : Resources) return Boolean is
     (Nearest_Cache_Ownership.Is_Allocated (Object.Nearest_Cache_Data));
   function Error_Length (Object : Resources) return Natural is
     (Error_Ownership.Length (Object.Error_Data));
   function Allocated_Bytes (Object : Resources) return Byte_Count is
     (Ownership.Used (Object.Allocation_Budget));
   function Cleanup_Succeeded (Object : Resources) return Boolean is
     (not Object.Cleanup_Failed and then Allocated_Bytes (Object) = 0);

   procedure Release (Object : in out Resources) is
      Status : Resource_Cleanup.Guard
        (Object.Allocation_Budget'Access, Object.Cleanup_Failed'Access);
      function Release_Histogram return Boolean is
        (Histogram_Ownership.Release
           (Object.Histogram_Data, Object.Allocation_Budget));
      function Release_Nearest_Cache return Boolean is
        (Nearest_Cache_Ownership.Release
           (Object.Nearest_Cache_Data, Object.Allocation_Budget));
      function Release_Error_Buffer return Boolean is
        (Error_Ownership.Release
           (Object.Error_Data, Object.Allocation_Budget));
      procedure Try_Histogram is new Resource_Cleanup.Attempt
        (Release_Histogram);
      procedure Try_Nearest_Cache is new Resource_Cleanup.Attempt
        (Release_Nearest_Cache);
      procedure Try_Error_Buffer is new Resource_Cleanup.Attempt
        (Release_Error_Buffer);
   begin
      Try_Histogram (Status);
      Try_Nearest_Cache (Status);
      Try_Error_Buffer (Status);
   end Release;

   overriding procedure Finalize (Object : in out Resources) is
   begin
      Release (Object);
   end Finalize;
end Giflib.Internal.Quantization_Storage;
