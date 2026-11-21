with Giflib.Streams;
with Project_Tools.Test_Fixtures;

package Giflib_Fuzz_Mutations is
   procedure Copy
     (Seed : Giflib.Streams.Byte_Array;
      Buffer : in out Giflib.Streams.Byte_Array;
      Length : out Positive);
   procedure Apply
     (Iteration : Positive;
      Buffer : in out Giflib.Streams.Byte_Array;
      Length : in out Positive;
      State : in out Project_Tools.Test_Fixtures.Deterministic_Seed);
end Giflib_Fuzz_Mutations;
