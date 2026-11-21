with Giflib.Streams;

package Giflib_Fuzz_Seed_Corpus is
   function Literal return Giflib.Streams.Byte_Array;
   function Load
     (Root : String; Relative_Path : String) return Giflib.Streams.Byte_Array;
end Giflib_Fuzz_Seed_Corpus;
