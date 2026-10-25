package Giflib.Internal.Metadata_Store.Testing is
   procedure Corrupt_First_Chunk_Span (Object : in out Store);
   procedure Corrupt_Payload_Length (Object : in out Store);
   procedure Corrupt_Sub_Block_Count (Object : in out Store);
   procedure Repair_Descriptor (Object : in out Store);
end Giflib.Internal.Metadata_Store.Testing;
