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
   function Is_Released (Object : Resources) return Boolean is
     (not Histogram_Ownership.Is_Allocated (Object.Histogram_Data)
      and then not Nearest_Cache_Ownership.Is_Allocated
        (Object.Nearest_Cache_Data)
      and then not Error_Ownership.Is_Allocated (Object.Error_Data));
   function Cleanup_Succeeded (Object : Resources) return Boolean is
     (Object.Cleanup_State = Cleanup.Cleanup_Complete
      and then Is_Released (Object)
      and then Allocated_Bytes (Object) = 0);

   function Release
     (Object : in out Resources) return Cleanup.Cleanup_Outcome
   is
      Outcome : Cleanup.Cleanup_Outcome;
      function Release_Histogram return Cleanup.Cleanup_Outcome is
      begin
         return Histogram_Ownership.Release
           (Object.Histogram_Data, Object.Allocation_Budget);
      end Release_Histogram;
      function Release_Nearest_Cache return Cleanup.Cleanup_Outcome is
      begin
         return Nearest_Cache_Ownership.Release
           (Object.Nearest_Cache_Data, Object.Allocation_Budget);
      end Release_Nearest_Cache;
      function Release_Error_Buffer return Cleanup.Cleanup_Outcome is
      begin
         return Error_Ownership.Release
           (Object.Error_Data, Object.Allocation_Budget);
      end Release_Error_Buffer;
      procedure Try_Histogram is new Resource_Cleanup.Attempt
        (Release_Histogram);
      procedure Try_Nearest_Cache is new Resource_Cleanup.Attempt
        (Release_Nearest_Cache);
      procedure Try_Error_Buffer is new Resource_Cleanup.Attempt
        (Release_Error_Buffer);
   begin
      declare
         Status : Resource_Cleanup.Guard
           (Object.Allocation_Budget'Access, Object.Cleanup_State'Access);
      begin
         Try_Histogram (Status);
         Try_Nearest_Cache (Status);
         Try_Error_Buffer (Status);
         Outcome := Resource_Cleanup.Current_Outcome (Status);
      end;
      return Outcome;
   end Release;

   overriding procedure Finalize (Object : in out Resources) is
      Outcome : constant Cleanup.Cleanup_Outcome := Release (Object);
      pragma Unreferenced (Outcome);
   begin
      null;
   end Finalize;
end Giflib.Internal.Quantization_Storage;
