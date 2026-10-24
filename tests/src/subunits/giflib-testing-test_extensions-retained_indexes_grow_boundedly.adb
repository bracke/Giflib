separate (Giflib.Testing.Test_Extensions)
procedure Retained_Indexes_Grow_Boundedly
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);

   function Many_Extensions return Giflib.Streams.Byte_Array is
      Result : Giflib.Streams.Byte_Array (1 .. 99) := [others => 0];
      Position : Positive := 1;
      Header : constant Giflib.Streams.Byte_Array :=
        [71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 0, 0, 0];
   begin
      Result (Position .. Position + Header'Length - 1) := Header;
      Position := Position + Header'Length;
      for Index in 1 .. 17 loop
         Result (Position .. Position + 4) :=
           [16#21#, 16#FE#, 1, Giflib.Byte (Index), 0];
         Position := Position + 5;
      end loop;
      Result (Position) := 16#3B#;
      return Result;
   end Many_Extensions;

   function Many_Chunks return Giflib.Streams.Byte_Array is
      Result : Giflib.Streams.Byte_Array (1 .. 51) := [others => 0];
      Position : Positive := 1;
      Header : constant Giflib.Streams.Byte_Array :=
        [71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 0, 0, 0];
   begin
      Result (Position .. Position + Header'Length - 1) := Header;
      Position := Position + Header'Length;
      Result (Position .. Position + 1) := [16#21#, 16#FE#];
      Position := Position + 2;
      for Index in 1 .. 17 loop
         Result (Position .. Position + 1) := [1, Giflib.Byte (Index)];
         Position := Position + 2;
      end loop;
      Result (Position .. Position + 1) := [0, 16#3B#];
      return Result;
   end Many_Chunks;

   Extensions_Fixture : aliased constant Giflib.Streams.Byte_Array :=
     Many_Extensions;
   Chunks_Fixture : aliased constant Giflib.Streams.Byte_Array := Many_Chunks;
   Source : aliased Giflib.Streams.Memory_Source (Extensions_Fixture'Access);
   Decoder : Giflib.Decoding.Decoder (Source'Access);
   Chunk_Source : aliased Giflib.Streams.Memory_Source (Chunks_Fixture'Access);
   Chunk_Decoder : Giflib.Decoding.Decoder (Chunk_Source'Access);
   Header : Giflib.Decoding.Header_Info;
   Event : Giflib.Decoding.Decode_Event;
   Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
   Info : Giflib.Metadata.Extension_Info;
   Payload : Giflib.Streams.Byte_Array (1 .. 17);
   Count : Giflib.Byte_Count;
   Chunks : Natural;
   Outcome : Giflib.Results.Result;
begin
   Options.Retention := Giflib.Metadata.Retain_All_Exact_Bounded;
   Giflib.Streams.Open (Source);
   Outcome := Giflib.Decoding.Initialize
     (Decoder, Options);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   for Index in 1 .. 17 loop
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Giflib.Testing.Assertions.Require_Success (Outcome);
   end loop;
   Outcome := Giflib.Decoding.Retained_Extension_Info (Decoder, 17, Info);
   Assert
     (Giflib.Results.Succeeded (Outcome) and then Info.Payload_Length = 1,
      "grown extension index lost its last entry");
   Outcome := Giflib.Decoding.Copy_Retained_Extension_Payload
     (Decoder, 17, Payload, Count);
   Assert
     (Giflib.Results.Succeeded (Outcome)
      and then Count = 1
      and then Payload (1) = 17,
      "grown extension index returned the wrong payload");

   Giflib.Decoding.Finalize (Decoder);
   Giflib.Streams.Open (Chunk_Source);
   Outcome := Giflib.Decoding.Initialize
     (Chunk_Decoder, Options);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Read_Header (Chunk_Decoder, Header);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Next_Event (Chunk_Decoder, Event);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Retained_Extension_Chunk_Count
     (Chunk_Decoder, 1, Chunks);
   Assert
     (Giflib.Results.Succeeded (Outcome) and then Chunks = 17,
      "grown chunk index has the wrong length");
   Outcome := Giflib.Decoding.Copy_Retained_Extension_Chunk
     (Chunk_Decoder, 1, 17, Payload, Count);
   Assert
     (Giflib.Results.Succeeded (Outcome)
      and then Count = 1
      and then Payload (1) = 17,
      "grown chunk index returned the wrong chunk");
   Giflib.Decoding.Finalize (Chunk_Decoder);
end Retained_Indexes_Grow_Boundedly;

