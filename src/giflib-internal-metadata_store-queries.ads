private package Giflib.Internal.Metadata_Store.Queries is
   pragma Preelaborate;

   function Info_At
     (Object : Store;
      Index : Positive;
      Info : out Metadata.Extension_Info) return Results.Result;
   function Copy_Payload
     (Object : Store;
      Index : Positive;
      Target : out Streams.Byte_Array;
      Count : out Byte_Count) return Results.Result;
   function Chunk_Count
     (Object : Store;
      Index : Positive;
      Count : out Natural) return Results.Result;
   function Copy_Chunk
     (Object : Store;
      Index : Positive;
      Chunk_Index : Positive;
      Target : out Streams.Byte_Array;
      Count : out Byte_Count) return Results.Result;
end Giflib.Internal.Metadata_Store.Queries;
