with Giflib.Internal.Ownership;
with Giflib.Metadata;
with Giflib.Results;
with Giflib.Streams;

package Giflib.Internal.Decoder_Storage.Metadata_Operations is
   pragma Preelaborate;

   function Start
     (Object : in out Resources;
      Fault : in out Ownership.Fault_State;
      Retention : Giflib.Metadata.Retention_Policy;
      Maximum_Allocation : Byte_Count;
      Info : Giflib.Metadata.Extension_Info) return Results.Result;
   function Append
     (Object : in out Resources;
      Fault : in out Ownership.Fault_State;
      Data : Streams.Byte_Array;
      Maximum_Payload : Byte_Count;
      Maximum_Allocation : Byte_Count) return Results.Result;
   function Finish
     (Object : in out Resources;
      Info : Giflib.Metadata.Extension_Info) return Results.Result;

   function Count (Object : Resources) return Natural;
   function Info_At
     (Object : Resources;
      Index : Positive;
      Info : out Giflib.Metadata.Extension_Info) return Results.Result;
   function Copy_Payload
     (Object : Resources;
      Index : Positive;
      Target : out Streams.Byte_Array;
      Count : out Byte_Count) return Results.Result;
   function Chunk_Count
     (Object : Resources;
      Index : Positive;
      Count : out Natural) return Results.Result;
   function Copy_Chunk
     (Object : Resources;
      Index : Positive;
      Chunk_Index : Positive;
      Target : out Streams.Byte_Array;
      Count : out Byte_Count) return Results.Result;
end Giflib.Internal.Decoder_Storage.Metadata_Operations;
