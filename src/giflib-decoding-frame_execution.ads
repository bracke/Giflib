private package Giflib.Decoding.Frame_Execution
  with Preelaborate
is
   function Decode_Indices
     (Object : in out Decoder;
      Output : out Streams.Byte_Array) return Results.Result;
   function Composite
     (Object : in out Decoder;
      Target : out Streams.Byte_Array) return Results.Result;
   function Skip_Data (Object : in out Decoder) return Results.Result;
end Giflib.Decoding.Frame_Execution;
