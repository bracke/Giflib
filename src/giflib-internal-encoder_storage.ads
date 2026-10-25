with Ada.Finalization;
with Giflib.Internal.LZW_Encoding;
with Giflib.Internal.Owned_Buffers;
with Giflib.Internal.Ownership;
with Giflib.Quantization;

package Giflib.Internal.Encoder_Storage is
   pragma Preelaborate;
   use type Ownership.Allocation_Status;

   type Resources is new Ada.Finalization.Limited_Controlled with private;

   function Truecolor_Allocated (Object : Resources) return Boolean;
   function Truecolor_Length (Object : Resources) return Byte_Count;
   function LZW_Allocated (Object : Resources) return Boolean;

   function Ensure_Truecolor_Pixels
     (Object : in out Resources;
      Fault : in out Ownership.Fault_State;
      Required : Byte_Count;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome
     with Post =>
       (if Ensure_Truecolor_Pixels'Result.Status = Ownership.Allocation_Ready
        then Truecolor_Allocated (Object)
             and then Truecolor_Length (Object) >= Required);
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
   function Quantizer_Bytes (Object : Resources) return Byte_Count;

   procedure Release (Object : in out Resources);
   overriding procedure Finalize (Object : in out Resources);

private
   type Resources is new Ada.Finalization.Limited_Controlled with record
      Truecolor_Buffer : Owned_Buffers.Handle;
      Allocation_Budget : aliased Ownership.Byte_Budget;
      Quantizer_Data : Quantization.Workspace;
      LZW_Data : LZW_Encoding.Workspace_Handle;
      Cleanup_Failed : aliased Boolean := False;
   end record;
end Giflib.Internal.Encoder_Storage;
