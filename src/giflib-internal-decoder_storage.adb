with Giflib.Internal.Resource_Cleanup;

package body Giflib.Internal.Decoder_Storage is
   function Metadata
     (Object : aliased in out Resources) return not null access Metadata_Store.Store is
     (Object.Metadata_Storage'Access);
   function Budget
     (Object : aliased in out Resources) return not null access Ownership.Byte_Budget is
     (Object.Allocation_Budget'Access);
   function Canvas
     (Object : aliased in out Resources) return not null access Owned_Buffers.Handle is
     (Object.Canvas_Buffer'Access);
   function Snapshot
     (Object : aliased in out Resources) return not null access Owned_Buffers.Handle is
     (Object.Snapshot_Buffer'Access);
   function Frame_Scratch
     (Object : aliased in out Resources) return not null access Owned_Buffers.Handle is
     (Object.Frame_Scratch_Buffer'Access);
   function LZW_Workspace
     (Object : aliased in out Resources) return not null access LZW.Workspace_Handle is
     (Object.LZW_Data'Access);
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
   function Metadata_Count (Object : Resources) return Natural is
     (Metadata_Store.Count (Object.Metadata_Storage));
   function Metadata_Info
     (Object : Resources;
      Index : Positive;
      Info : out Giflib.Metadata.Extension_Info) return Results.Result
   is (Metadata_Store.Info_At (Object.Metadata_Storage, Index, Info));
   function Copy_Metadata_Payload
     (Object : Resources;
      Index : Positive;
      Target : out Streams.Byte_Array;
      Count : out Byte_Count) return Results.Result
   is (Metadata_Store.Copy_Payload
         (Object.Metadata_Storage, Index, Target, Count));
   function Metadata_Chunk_Count
     (Object : Resources;
      Index : Positive;
      Count : out Natural) return Results.Result
   is (Metadata_Store.Chunk_Count (Object.Metadata_Storage, Index, Count));
   function Copy_Metadata_Chunk
     (Object : Resources;
      Index : Positive;
      Chunk_Index : Positive;
      Target : out Streams.Byte_Array;
      Count : out Byte_Count) return Results.Result
   is (Metadata_Store.Copy_Chunk
         (Object.Metadata_Storage, Index, Chunk_Index, Target, Count));

   procedure Release (Object : in out Resources) is
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
      procedure Release_All is new Resource_Cleanup.Release_Five
        (Release_Metadata, Release_Canvas, Release_Snapshot,
         Release_Frame_Scratch, Release_LZW);
   begin
      Release_All (Object.Allocation_Budget, Object.Cleanup_Failed);
   end Release;

   overriding procedure Finalize (Object : in out Resources) is
   begin
      Release (Object);
   end Finalize;
end Giflib.Internal.Decoder_Storage;
