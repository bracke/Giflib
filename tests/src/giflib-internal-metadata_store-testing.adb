package body Giflib.Internal.Metadata_Store.Testing is
   procedure Corrupt_First_Chunk_Span (Object : in out Store) is
      Node : Extension_Node := Extension_Nodes.Element (Object.Entries, 1);
   begin
      Node.First_Chunk := Natural'Last;
      Extension_Nodes.Replace (Object.Entries, 1, Node);
   end Corrupt_First_Chunk_Span;
end Giflib.Internal.Metadata_Store.Testing;
