with Ada.Finalization;
with Giflib.Internal.LZW;
with Giflib.Internal.Metadata_Store;
with Giflib.Internal.Owned_Buffers;
with Giflib.Internal.Ownership;
with Giflib.Metadata;
with Giflib.Results;
with Giflib.Streams;

package Giflib.Internal.Decoder_Storage is
   pragma Preelaborate;

   type Resources is new Ada.Finalization.Limited_Controlled with private;

   function Metadata
     (Object : aliased in out Resources) return not null access Metadata_Store.Store;
   function Budget
     (Object : aliased in out Resources) return not null access Ownership.Byte_Budget;
   function Canvas
     (Object : aliased in out Resources) return not null access Owned_Buffers.Handle;
   function Snapshot
     (Object : aliased in out Resources) return not null access Owned_Buffers.Handle;
   function Frame_Scratch
     (Object : aliased in out Resources) return not null access Owned_Buffers.Handle;
   function LZW_Workspace
     (Object : aliased in out Resources) return not null access LZW.Workspace_Handle;
   function Cleanup_Succeeded (Object : Resources) return Boolean;
   function Is_Released (Object : Resources) return Boolean;
   function Allocated_Bytes (Object : Resources) return Byte_Count;
   function Metadata_Count (Object : Resources) return Natural;
   function Metadata_Info
     (Object : Resources;
      Index : Positive;
      Info : out Giflib.Metadata.Extension_Info) return Results.Result;
   function Copy_Metadata_Payload
     (Object : Resources;
      Index : Positive;
      Target : out Streams.Byte_Array;
      Count : out Byte_Count) return Results.Result;
   function Metadata_Chunk_Count
     (Object : Resources;
      Index : Positive;
      Count : out Natural) return Results.Result;
   function Copy_Metadata_Chunk
     (Object : Resources;
      Index : Positive;
      Chunk_Index : Positive;
      Target : out Streams.Byte_Array;
      Count : out Byte_Count) return Results.Result;

   procedure Release (Object : in out Resources);
   overriding procedure Finalize (Object : in out Resources);

private
   type Resources is new Ada.Finalization.Limited_Controlled with record
      Metadata_Storage : aliased Metadata_Store.Store;
      Allocation_Budget : aliased Ownership.Byte_Budget;
      Canvas_Buffer : aliased Owned_Buffers.Handle;
      Snapshot_Buffer : aliased Owned_Buffers.Handle;
      Frame_Scratch_Buffer : aliased Owned_Buffers.Handle;
      LZW_Data : aliased LZW.Workspace_Handle;
      Cleanup_Failed : Boolean := False;
   end record;
end Giflib.Internal.Decoder_Storage;
