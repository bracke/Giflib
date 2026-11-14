private package Giflib.Internal.Metadata_Store.Validation is
   pragma Preelaborate;

   function Invalid_Store return Results.Result;
   function Stored_Length (Node : Extension_Node) return Byte_Count;
   function Stored_Chunk_Count (Node : Extension_Node) return Natural;
   function Node_Is_Valid
     (Object : Store; Index : Positive; Node : Extension_Node) return Boolean;
   function Load_Node
     (Object : Store;
      Index : Positive;
      Node : out Extension_Node) return Results.Result;
end Giflib.Internal.Metadata_Store.Validation;
