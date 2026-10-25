with Ada.Finalization;
with Giflib.Internal.LZW;
with Giflib.Internal.Metadata_Store;
with Giflib.Internal.Owned_Buffers;
with Giflib.Internal.Ownership;

package Giflib.Internal.Decoder_Storage is
   pragma Preelaborate;

   type Resources is new Ada.Finalization.Limited_Controlled with record
      Metadata_Storage : Metadata_Store.Store;
      Allocation_Budget : aliased Ownership.Byte_Budget;
      Canvas : Owned_Buffers.Handle;
      Snapshot : Owned_Buffers.Handle;
      Frame_Scratch : Owned_Buffers.Handle;
      LZW_Workspace : LZW.Workspace_Handle;
      Cleanup_Failed : Boolean := False;
   end record;

   procedure Release (Object : in out Resources);
   overriding procedure Finalize (Object : in out Resources);
end Giflib.Internal.Decoder_Storage;
