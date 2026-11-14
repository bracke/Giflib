package body Giflib.Internal.Metadata_Store.Testing is
   procedure Corrupt_First_Chunk_Span (Object : in out Store) is
      Node : Extension_Node := Extension_Nodes.Element (Object.Entries, 1);
   begin
      Node.Span :=
        (Present => True,
         First => Positive'Last,
         Count => Node.Span.Count,
         Length => Node.Span.Length);
      Extension_Nodes.Replace (Object.Entries, 1, Node);
   end Corrupt_First_Chunk_Span;

   procedure Corrupt_Payload_Length (Object : in out Store) is
      Node : Extension_Node := Extension_Nodes.Element (Object.Entries, 1);
   begin
      Node.Info.Payload_Length := Node.Span.Length + 1;
      Extension_Nodes.Replace (Object.Entries, 1, Node);
   end Corrupt_Payload_Length;

   procedure Corrupt_Sub_Block_Count (Object : in out Store) is
      Node : Extension_Node := Extension_Nodes.Element (Object.Entries, 1);
   begin
      Node.Info.Sub_Block_Count := Node.Span.Count + 1;
      Extension_Nodes.Replace (Object.Entries, 1, Node);
   end Corrupt_Sub_Block_Count;

   procedure Repair_Descriptor (Object : in out Store) is
      Node : Extension_Node := Extension_Nodes.Element (Object.Entries, 1);
   begin
      Node.Info.Payload_Length :=
        (if Node.Span.Present then Node.Span.Length else 0);
      Node.Info.Sub_Block_Count :=
        (if Node.Span.Present then Node.Span.Count else 0);
      Extension_Nodes.Replace (Object.Entries, 1, Node);
   end Repair_Descriptor;
end Giflib.Internal.Metadata_Store.Testing;
