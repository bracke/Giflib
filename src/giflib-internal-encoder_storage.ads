with Ada.Finalization;
with Giflib.Internal.LZW_Encoding;
with Giflib.Internal.Owned_Buffers;
with Giflib.Internal.Ownership;
with Giflib.Quantization;

package Giflib.Internal.Encoder_Storage is
   pragma Preelaborate;

   type Resources is new Ada.Finalization.Limited_Controlled with private;

   function Truecolor_Pixels
     (Object : aliased in out Resources) return not null access Owned_Buffers.Handle;
   function Budget
     (Object : aliased in out Resources) return not null access Ownership.Byte_Budget;
   function Quantizer
     (Object : aliased in out Resources) return not null access Quantization.Workspace;
   function LZW_Workspace
     (Object : aliased in out Resources)
      return not null access LZW_Encoding.Workspace_Handle;
   function Cleanup_Succeeded (Object : Resources) return Boolean;
   function Is_Released (Object : Resources) return Boolean;
   function Allocated_Bytes (Object : Resources) return Byte_Count;
   function Quantizer_Bytes (Object : Resources) return Byte_Count;
   function Quantizer_Cleanup_Succeeded (Object : Resources) return Boolean;

   procedure Release (Object : in out Resources);
   overriding procedure Finalize (Object : in out Resources);

private
   type Resources is new Ada.Finalization.Limited_Controlled with record
      Truecolor_Buffer : aliased Owned_Buffers.Handle;
      Allocation_Budget : aliased Ownership.Byte_Budget;
      Quantizer_Data : aliased Quantization.Workspace;
      LZW_Data : aliased LZW_Encoding.Workspace_Handle;
      Cleanup_Failed : Boolean := False;
   end record;
end Giflib.Internal.Encoder_Storage;
