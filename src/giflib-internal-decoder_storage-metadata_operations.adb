package body Giflib.Internal.Decoder_Storage.Metadata_Operations is
   function Start
     (Object : in out Resources;
      Fault : in out Ownership.Fault_State;
      Retention : Giflib.Metadata.Retention_Policy;
      Maximum_Allocation : Byte_Count;
      Info : Giflib.Metadata.Extension_Info) return Results.Result
   is (Metadata_Store.Start
         (Object.Metadata_Storage, Retention, Maximum_Allocation,
          Object.Allocation_Budget, Fault, Info));

   function Append
     (Object : in out Resources;
      Fault : in out Ownership.Fault_State;
      Data : Streams.Byte_Array;
      Maximum_Payload : Byte_Count;
      Maximum_Allocation : Byte_Count) return Results.Result
   is (Metadata_Store.Append
         (Object.Metadata_Storage, Data, Maximum_Payload, Maximum_Allocation,
          Object.Allocation_Budget, Fault));

   function Finish
     (Object : in out Resources;
      Info : Giflib.Metadata.Extension_Info) return Results.Result
   is (Metadata_Store.Finish (Object.Metadata_Storage, Info));

   function Count (Object : Resources) return Natural is
     (Metadata_Store.Count (Object.Metadata_Storage));
   function Info_At
     (Object : Resources;
      Index : Positive;
      Info : out Giflib.Metadata.Extension_Info) return Results.Result
   is (Metadata_Store.Info_At (Object.Metadata_Storage, Index, Info));
   function Copy_Payload
     (Object : Resources;
      Index : Positive;
      Target : out Streams.Byte_Array;
      Count : out Byte_Count) return Results.Result
   is (Metadata_Store.Copy_Payload
         (Object.Metadata_Storage, Index, Target, Count));
   function Chunk_Count
     (Object : Resources;
      Index : Positive;
      Count : out Natural) return Results.Result
   is (Metadata_Store.Chunk_Count (Object.Metadata_Storage, Index, Count));
   function Copy_Chunk
     (Object : Resources;
      Index : Positive;
      Chunk_Index : Positive;
      Target : out Streams.Byte_Array;
      Count : out Byte_Count) return Results.Result
   is (Metadata_Store.Copy_Chunk
         (Object.Metadata_Storage, Index, Chunk_Index, Target, Count));
end Giflib.Internal.Decoder_Storage.Metadata_Operations;
