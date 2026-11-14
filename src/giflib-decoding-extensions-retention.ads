private package Giflib.Decoding.Extensions.Retention
  with Preelaborate
is
   function Start
     (Object : in out Decoder;
      Info : Metadata.Extension_Info) return Results.Result;

   function Append
     (Object : in out Decoder;
      Data : Streams.Byte_Array) return Results.Result;

   function Finish
     (Object : in out Decoder;
      Info : Metadata.Extension_Info) return Results.Result;
end Giflib.Decoding.Extensions.Retention;
