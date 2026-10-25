package body Giflib.Internal.Metadata_Store.Testing is
   procedure Corrupt_First_Chunk_Span (Object : in out Store) is
      Node : Extension_Node := Extension_Nodes.Element (Object.Entries, 1);
   begin
      Node.First_Chunk := Natural'Last;
      Extension_Nodes.Replace (Object.Entries, 1, Node);
   end Corrupt_First_Chunk_Span;

   procedure Corrupt_Payload_Length (Object : in out Store) is
      Node : Extension_Node := Extension_Nodes.Element (Object.Entries, 1);
   begin
      Node.Info.Payload_Length := Node.Retained_Length + 1;
      Extension_Nodes.Replace (Object.Entries, 1, Node);
   end Corrupt_Payload_Length;

   procedure Corrupt_Sub_Block_Count (Object : in out Store) is
      Node : Extension_Node := Extension_Nodes.Element (Object.Entries, 1);
   begin
      Node.Info.Sub_Block_Count := Node.Chunk_Count + 1;
      Extension_Nodes.Replace (Object.Entries, 1, Node);
   end Corrupt_Sub_Block_Count;

   procedure Repair_Descriptor (Object : in out Store) is
      Node : Extension_Node := Extension_Nodes.Element (Object.Entries, 1);
   begin
      Node.Info.Payload_Length := Node.Retained_Length;
      Node.Info.Sub_Block_Count := Node.Chunk_Count;
      Extension_Nodes.Replace (Object.Entries, 1, Node);
   end Repair_Descriptor;
end Giflib.Internal.Metadata_Store.Testing;
