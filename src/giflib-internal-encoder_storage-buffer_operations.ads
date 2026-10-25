with Giflib.Results;
with Giflib.Streams;

package Giflib.Internal.Encoder_Storage.Buffer_Operations is
   pragma Preelaborate;

   function Update_Truecolor
     (Object : in out Resources;
      Pixel_Count : Byte_Count;
      Process : not null access function
        (Pixels : in out Streams.Byte_Array) return Results.Result)
      return Results.Result;

end Giflib.Internal.Encoder_Storage.Buffer_Operations;
