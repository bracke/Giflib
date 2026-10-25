with Giflib.Internal.Resource_Cleanup;

package body Giflib.Internal.Decoder_Storage is
   function Ensure_Frame_Scratch
     (Object : in out Resources;
      Fault : in out Ownership.Fault_State;
      Required : Byte_Count;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome
   is (Owned_Buffers.Ensure
         (Object.Frame_Scratch_Buffer, Object.Allocation_Budget,
          Fault, Required, Maximum));
   function Ensure_Canvas
     (Object : in out Resources;
      Fault : in out Ownership.Fault_State;
      Required : Byte_Count;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome
   is (Owned_Buffers.Ensure
         (Object.Canvas_Buffer, Object.Allocation_Budget,
          Fault, Required, Maximum));
   function Ensure_Snapshot
     (Object : in out Resources;
      Fault : in out Ownership.Fault_State;
      Required : Byte_Count;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome
   is (Owned_Buffers.Ensure
         (Object.Snapshot_Buffer, Object.Allocation_Budget,
          Fault, Required, Maximum));
   function Ensure_LZW
     (Object : in out Resources;
      Fault : in out Ownership.Fault_State;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome
   is (LZW.Ensure
         (Object.LZW_Data, Object.Allocation_Budget, Fault, Maximum));
   function Canvas_Allocated (Object : Resources) return Boolean is
     (Owned_Buffers.Is_Allocated (Object.Canvas_Buffer));
   function Snapshot_Allocated (Object : Resources) return Boolean is
     (Owned_Buffers.Is_Allocated (Object.Snapshot_Buffer));
   function Frame_Scratch_Allocated (Object : Resources) return Boolean is
     (Owned_Buffers.Is_Allocated (Object.Frame_Scratch_Buffer));
   function LZW_Allocated (Object : Resources) return Boolean is
     (LZW.Is_Allocated (Object.LZW_Data));
   function Canvas_Length (Object : Resources) return Byte_Count is
     (Owned_Buffers.Length (Object.Canvas_Buffer));
   function Snapshot_Length (Object : Resources) return Byte_Count is
     (Owned_Buffers.Length (Object.Snapshot_Buffer));
   function Frame_Scratch_Length (Object : Resources) return Byte_Count is
     (Owned_Buffers.Length (Object.Frame_Scratch_Buffer));
   function Cleanup_Succeeded (Object : Resources) return Boolean is
     (not Object.Cleanup_Failed);
   function Is_Released (Object : Resources) return Boolean is
     (Metadata_Store.Is_Released (Object.Metadata_Storage)
      and then not Owned_Buffers.Is_Allocated (Object.Canvas_Buffer)
      and then not Owned_Buffers.Is_Allocated (Object.Snapshot_Buffer)
      and then not Owned_Buffers.Is_Allocated (Object.Frame_Scratch_Buffer)
      and then not LZW.Is_Allocated (Object.LZW_Data));
   function Allocated_Bytes (Object : Resources) return Byte_Count is
     (Ownership.Used (Object.Allocation_Budget));

   procedure Release (Object : in out Resources) is
      Status : Resource_Cleanup.Guard
        (Object.Allocation_Budget'Access, Object.Cleanup_Failed'Access);
      function Release_Metadata return Boolean is
        (Metadata_Store.Release
           (Object.Metadata_Storage, Object.Allocation_Budget));
      function Release_Canvas return Boolean is
        (Owned_Buffers.Release (Object.Canvas_Buffer, Object.Allocation_Budget));
      function Release_Snapshot return Boolean is
        (Owned_Buffers.Release (Object.Snapshot_Buffer, Object.Allocation_Budget));
      function Release_Frame_Scratch return Boolean is
        (Owned_Buffers.Release
           (Object.Frame_Scratch_Buffer, Object.Allocation_Budget));
      function Release_LZW return Boolean is
        (LZW.Release (Object.LZW_Data, Object.Allocation_Budget));
      procedure Try_Metadata is new Resource_Cleanup.Attempt (Release_Metadata);
      procedure Try_Canvas is new Resource_Cleanup.Attempt (Release_Canvas);
      procedure Try_Snapshot is new Resource_Cleanup.Attempt (Release_Snapshot);
      procedure Try_Frame_Scratch is new Resource_Cleanup.Attempt
        (Release_Frame_Scratch);
      procedure Try_LZW is new Resource_Cleanup.Attempt (Release_LZW);
   begin
      Try_Metadata (Status);
      Try_Canvas (Status);
      Try_Snapshot (Status);
      Try_Frame_Scratch (Status);
      Try_LZW (Status);
   end Release;

   overriding procedure Finalize (Object : in out Resources) is
   begin
      Release (Object);
   end Finalize;
end Giflib.Internal.Decoder_Storage;
