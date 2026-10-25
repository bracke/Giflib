with Ada.Finalization;
with Giflib.Internal.LZW_Encoding;
with Giflib.Internal.Owned_Buffers;
with Giflib.Internal.Ownership;
with Giflib.Quantization;

package Giflib.Internal.Encoder_Storage is
   pragma Preelaborate;

   type Resources is new Ada.Finalization.Limited_Controlled with record
      Truecolor_Pixels : Owned_Buffers.Handle;
      Allocation_Budget : aliased Ownership.Byte_Budget;
      Quantizer : Quantization.Workspace;
      LZW_Workspace : LZW_Encoding.Workspace_Handle;
      Cleanup_Failed : Boolean := False;
   end record;

   procedure Release (Object : in out Resources);
   overriding procedure Finalize (Object : in out Resources);
end Giflib.Internal.Encoder_Storage;
