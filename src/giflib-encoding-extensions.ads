private package Giflib.Encoding.Extensions is
   pragma Preelaborate;

   function Add
     (Object : in out Encoder;
      Descriptor : Extension_Descriptor;
      Payload : Streams.Byte_Array) return Results.Result;

   function Add_Exact
     (Object : in out Encoder;
      Descriptor : Extension_Descriptor;
      Payload : Streams.Byte_Array;
      Chunk_Lengths : Chunk_Length_Array) return Results.Result;
end Giflib.Encoding.Extensions;
