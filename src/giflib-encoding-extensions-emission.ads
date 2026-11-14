private package Giflib.Encoding.Extensions.Emission
  with Preelaborate
is
   function Emit
     (Object : in out Encoder;
      Descriptor : Extension_Descriptor;
      Payload : Streams.Byte_Array;
      Fixed_Length : Natural;
      Plan : Chunk_Plan) return Results.Result;
end Giflib.Encoding.Extensions.Emission;
