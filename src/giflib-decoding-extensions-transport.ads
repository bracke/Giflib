private package Giflib.Decoding.Extensions.Transport
  with Preelaborate
is
   function Truncated
     (Object : Decoder;
      Info : Metadata.Extension_Info;
      Outcome : Results.Result) return Results.Result;

   function Read_Fixed_Block
     (Object : in out Decoder;
      Info : Metadata.Extension_Info;
      Data : out Streams.Byte_Array) return Results.Result;

   function Read_Sub_Blocks
     (Object : in out Decoder;
      Info : in out Metadata.Extension_Info;
      First_Data : out Streams.Byte_Array;
      First_Length : out Natural) return Results.Result;
end Giflib.Decoding.Extensions.Transport;
