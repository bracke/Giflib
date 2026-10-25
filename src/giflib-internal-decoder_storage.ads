with Ada.Finalization;
with Giflib.Internal.LZW;
with Giflib.Internal.Metadata_Store;
with Giflib.Internal.Owned_Buffers;
with Giflib.Internal.Ownership;

package Giflib.Internal.Decoder_Storage is
   pragma Preelaborate;
   use type Ownership.Allocation_Status;

   type Resources is new Ada.Finalization.Limited_Controlled with private;

   function Canvas_Allocated (Object : Resources) return Boolean;
   function Snapshot_Allocated (Object : Resources) return Boolean;
   function Frame_Scratch_Allocated (Object : Resources) return Boolean;
   function LZW_Allocated (Object : Resources) return Boolean;
   function Canvas_Length (Object : Resources) return Byte_Count;
   function Snapshot_Length (Object : Resources) return Byte_Count;
   function Frame_Scratch_Length (Object : Resources) return Byte_Count;

   function Ensure_Frame_Scratch
     (Object : in out Resources;
      Fault : in out Ownership.Fault_State;
      Required : Byte_Count;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome
     with Post =>
       (if Ensure_Frame_Scratch'Result.Status = Ownership.Allocation_Ready
        then Frame_Scratch_Allocated (Object)
             and then Frame_Scratch_Length (Object) >= Required);
   function Ensure_Canvas
     (Object : in out Resources;
      Fault : in out Ownership.Fault_State;
      Required : Byte_Count;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome
     with Post =>
       (if Ensure_Canvas'Result.Status = Ownership.Allocation_Ready
        then Canvas_Allocated (Object)
             and then Canvas_Length (Object) >= Required);
   function Ensure_Snapshot
     (Object : in out Resources;
      Fault : in out Ownership.Fault_State;
      Required : Byte_Count;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome
     with Post =>
       (if Ensure_Snapshot'Result.Status = Ownership.Allocation_Ready
        then Snapshot_Allocated (Object)
             and then Snapshot_Length (Object) >= Required);
   function Ensure_LZW
     (Object : in out Resources;
      Fault : in out Ownership.Fault_State;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome
     with Post =>
       (if Ensure_LZW'Result.Status = Ownership.Allocation_Ready
        then LZW_Allocated (Object));

   function Cleanup_Succeeded (Object : Resources) return Boolean;
   function Is_Released (Object : Resources) return Boolean;
   function Allocated_Bytes (Object : Resources) return Byte_Count;

   procedure Release (Object : in out Resources);
   overriding procedure Finalize (Object : in out Resources);

private
   type Resources is new Ada.Finalization.Limited_Controlled with record
      Metadata_Storage : Metadata_Store.Store;
      Allocation_Budget : aliased Ownership.Byte_Budget;
      Canvas_Buffer : Owned_Buffers.Handle;
      Snapshot_Buffer : Owned_Buffers.Handle;
      Frame_Scratch_Buffer : Owned_Buffers.Handle;
      LZW_Data : LZW.Workspace_Handle;
      Cleanup_Failed : aliased Boolean := False;
   end record;
end Giflib.Internal.Decoder_Storage;
