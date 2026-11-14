private package Giflib.Encoding.Extensions is
   pragma Preelaborate;

   type Chunk_Plan_Kind is (Automatic_Chunks, Exact_Chunks);
   type Chunk_Plan (Kind : Chunk_Plan_Kind; Count : Natural) is record
      case Kind is
         when Automatic_Chunks =>
            null;
         when Exact_Chunks =>
            Lengths : Chunk_Length_Array (1 .. Count);
      end case;
   end record;

   function Add
     (Object : in out Encoder;
      Descriptor : Extension_Descriptor;
      Payload : Streams.Byte_Array) return Results.Result;

   function Add_Exact
     (Object : in out Encoder;
      Descriptor : Extension_Descriptor;
      Payload : Streams.Byte_Array;
      Chunk_Lengths : Chunk_Length_Array) return Results.Result;
end Giflib.Encoding.Extensions;
