with Giflib_API_Consumer;
with Giflib.Encoding;
with Giflib.Metadata;
with Giflib.Results;
with Giflib.Streams;

procedure Giflib_Public_API_Check is
   pragma Assert (Giflib_API_Consumer.Streams_Available);
   Storage : aliased Giflib.Streams.Byte_Array :=
     [for I in 1 .. 256 => 0];
   Destination : aliased Giflib.Streams.Fixed_Buffer_Destination
     (Storage'Access);
   Encoder : Giflib.Encoding.Encoder (Destination'Access);
   Outcome : Giflib.Results.Result;
begin
   Giflib.Streams.Open (Destination);
   Outcome := Giflib.Encoding.Initialize (Encoder);
   pragma Assert (Giflib.Results.Succeeded (Outcome));
   Outcome := Giflib.Encoding.Define_Screen (Encoder, (others => <>));
   pragma Assert (Giflib.Results.Succeeded (Outcome));
   Outcome := Giflib.Encoding.Add_Extension
     (Encoder,
      (Kind => Giflib.Encoding.Comment_Extension),
      [1 => 16#41#]);
   pragma Assert (Giflib.Results.Succeeded (Outcome));
   Outcome := Giflib.Encoding.Add_Decoded_Extension
     (Encoder,
      (Kind => Giflib.Metadata.Comment_Extension,
       others => <>),
      [1 => 16#42#]);
   pragma Assert (Giflib.Results.Succeeded (Outcome));
   Outcome := Giflib.Encoding.Add_Extension_Exact
     (Encoder,
      (Kind => Giflib.Encoding.Comment_Extension),
      [1 => 16#43#],
      [1 => 1]);
   pragma Assert (Giflib.Results.Succeeded (Outcome));
   Outcome := Giflib.Encoding.Add_Decoded_Extension_Exact
     (Encoder,
      (Kind => Giflib.Metadata.Comment_Extension,
       others => <>),
      [1 => 16#44#],
      [1 => 1]);
   pragma Assert (Giflib.Results.Succeeded (Outcome));
   Outcome := Giflib.Encoding.Finish (Encoder);
   pragma Assert (Giflib.Results.Succeeded (Outcome));
end Giflib_Public_API_Check;
