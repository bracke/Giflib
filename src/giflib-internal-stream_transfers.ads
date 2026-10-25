with Giflib.Results;
with Giflib.Streams;

package Giflib.Internal.Stream_Transfers
  with Preelaborate
is
   function Read_Exact
     (Object : in out Streams.Source'Class;
      Buffer : out Streams.Byte_Array) return Results.Result;
   function Skip_Exact
     (Object : in out Streams.Source'Class;
      Count : Byte_Count) return Results.Result;
   function Write_All
     (Object : in out Streams.Destination'Class;
      Buffer : Streams.Byte_Array;
      Count : out Byte_Count) return Results.Result;
end Giflib.Internal.Stream_Transfers;
