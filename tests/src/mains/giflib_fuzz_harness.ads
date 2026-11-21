with Giflib.Streams;

package Giflib_Fuzz_Harness is
   procedure Verify_Stress_Seed
     (Storage : aliased Giflib.Streams.Byte_Array;
      Uniform : Boolean);

   procedure Exercise
     (Storage : aliased Giflib.Streams.Byte_Array;
      Length : Positive)
     with Pre => Length <= Storage'Length;
end Giflib_Fuzz_Harness;
