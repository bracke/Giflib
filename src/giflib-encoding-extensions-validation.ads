private package Giflib.Encoding.Extensions.Validation
  with Preelaborate
is
   function Request
     (Object : Encoder;
      Descriptor : Extension_Descriptor;
      Payload : Streams.Byte_Array;
      Fixed_Length : out Natural) return Results.Result;

   function Chunking
     (Payload : Streams.Byte_Array;
      Fixed_Length : Natural;
      Plan : Chunk_Plan) return Results.Result;
end Giflib.Encoding.Extensions.Validation;
