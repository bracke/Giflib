with Giflib.Results;
with Giflib.Streams;

package Giflib.Internal.LZW_Encoding is
   pragma Preelaborate;

   function Encode
     (Object : in out Streams.Destination'Class;
      Input : Streams.Byte_Array;
      Minimum_Code_Size : Byte;
      Max_Work : Byte_Count;
      Max_Compressed_Bytes : Byte_Count;
      Max_Wire_Bytes : Byte_Count;
      Compressed_Bytes : out Byte_Count;
      Interlace_Width : Natural := 0;
      Interlace_Height : Natural := 0) return Results.Result;
end Giflib.Internal.LZW_Encoding;
