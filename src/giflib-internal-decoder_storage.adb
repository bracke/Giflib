package body Giflib.Internal.Decoder_Storage is
   procedure Release (Object : in out Resources) is
      Failed : Boolean := False;
      function Release_Metadata return Boolean is
        (Metadata_Store.Release
           (Object.Metadata_Storage, Object.Allocation_Budget));
      function Release_Canvas return Boolean is
        (Owned_Buffers.Release (Object.Canvas, Object.Allocation_Budget));
      function Release_Snapshot return Boolean is
        (Owned_Buffers.Release (Object.Snapshot, Object.Allocation_Budget));
      function Release_Frame_Scratch return Boolean is
        (Owned_Buffers.Release
           (Object.Frame_Scratch, Object.Allocation_Budget));
      function Release_LZW return Boolean is
        (LZW.Release (Object.LZW_Workspace, Object.Allocation_Budget));
      procedure Try_Metadata is new Ownership.Attempt_Release
        (Release_Metadata);
      procedure Try_Canvas is new Ownership.Attempt_Release (Release_Canvas);
      procedure Try_Snapshot is new Ownership.Attempt_Release
        (Release_Snapshot);
      procedure Try_Frame_Scratch is new Ownership.Attempt_Release
        (Release_Frame_Scratch);
      procedure Try_LZW is new Ownership.Attempt_Release (Release_LZW);
   begin
      Try_Metadata (Failed);
      Try_Canvas (Failed);
      Try_Snapshot (Failed);
      Try_Frame_Scratch (Failed);
      Try_LZW (Failed);
      Object.Cleanup_Failed :=
        Object.Cleanup_Failed
        or else Failed
        or else not Ownership.Healthy (Object.Allocation_Budget);
   end Release;

   overriding procedure Finalize (Object : in out Resources) is
   begin
      Release (Object);
   end Finalize;
end Giflib.Internal.Decoder_Storage;
