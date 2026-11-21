with Giflib.Streams;

package Giflib_Fuzz_Source is
   type Prefix_Source
     (Storage : not null access constant Giflib.Streams.Byte_Array;
      Length : Positive) is limited new Giflib.Streams.Source with private;

   overriding function Read
     (Object : in out Prefix_Source;
      Buffer : out Giflib.Streams.Byte_Array)
      return Giflib.Streams.Source_Result;
   overriding function Offset
     (Object : Prefix_Source) return Giflib.Source_Offset;
   overriding function Skip
     (Object : in out Prefix_Source;
      Count : Giflib.Byte_Count) return Giflib.Streams.Source_Result;
private
   type Prefix_Source
     (Storage : not null access constant Giflib.Streams.Byte_Array;
      Length : Positive) is limited new Giflib.Streams.Source with record
      Position : Natural := 0;
   end record;
end Giflib_Fuzz_Source;
