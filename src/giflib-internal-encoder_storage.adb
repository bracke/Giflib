with Giflib.Internal.Resource_Cleanup;

package body Giflib.Internal.Encoder_Storage is
   function Ensure_Truecolor_Pixels
     (Object : in out Resources;
      Fault : in out Ownership.Fault_State;
      Required : Byte_Count;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome
   is (Owned_Buffers.Ensure
         (Object.Truecolor_Buffer, Object.Allocation_Budget,
          Fault, Required, Maximum));
   function Ensure_LZW
     (Object : in out Resources;
      Fault : in out Ownership.Fault_State;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome
   is (LZW_Encoding.Ensure
         (Object.LZW_Data, Object.Allocation_Budget, Fault, Maximum));
   function Truecolor_Allocated (Object : Resources) return Boolean is
     (Owned_Buffers.Is_Allocated (Object.Truecolor_Buffer));
   function Truecolor_Length (Object : Resources) return Byte_Count is
     (Owned_Buffers.Length (Object.Truecolor_Buffer));
   function LZW_Allocated (Object : Resources) return Boolean is
     (LZW_Encoding.Is_Allocated (Object.LZW_Data));
   function Is_Released (Object : Resources) return Boolean is
     (not Owned_Buffers.Is_Allocated (Object.Truecolor_Buffer)
      and then not LZW_Encoding.Is_Allocated (Object.LZW_Data));
   function Allocated_Bytes (Object : Resources) return Byte_Count is
     (Ownership.Used (Object.Allocation_Budget));
   function First_Cleanup_Status
     (Object : Resources) return Cleanup.Cleanup_Status
   is (Object.Cleanup_State);
   function Release
     (Object : in out Resources) return Cleanup.Cleanup_Outcome
   is
      Outcome : Cleanup.Cleanup_Outcome;
      function Release_Buffer return Cleanup.Cleanup_Outcome is
      begin
         return Owned_Buffers.Release
           (Object.Truecolor_Buffer, Object.Allocation_Budget);
      end Release_Buffer;
      function Release_LZW return Cleanup.Cleanup_Outcome is
      begin
         return LZW_Encoding.Release
           (Object.LZW_Data, Object.Allocation_Budget);
      end Release_LZW;
      procedure Try_Buffer is new Resource_Cleanup.Attempt (Release_Buffer);
      procedure Try_LZW is new Resource_Cleanup.Attempt (Release_LZW);
   begin
      declare
         Status : Resource_Cleanup.Guard
           (Object.Allocation_Budget'Access, Object.Cleanup_State'Access);
      begin
         Try_Buffer (Status);
         Try_LZW (Status);
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
end Giflib.Internal.Encoder_Storage;
