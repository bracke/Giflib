with Giflib.Results;
with Giflib.Streams;

package Giflib.Internal.Encoder_Storage.Frame_Operations is
   pragma Preelaborate;

   function Encode_LZW
     (Object : in out Resources;
      Destination : in out Streams.Destination'Class;
      Input : Streams.Byte_Array;
      Minimum_Code_Size : Byte;
      Max_Work : Byte_Count;
      Max_Compressed_Bytes : Byte_Count;
      Max_Wire_Bytes : Byte_Count;
      Compressed_Bytes : out Byte_Count;
      Wire_Bytes : out Byte_Count;
      Maximum_Index : Byte := 255;
      Interlace_Width : Natural := 0;
      Interlace_Height : Natural := 0) return Results.Result;
end Giflib.Internal.Encoder_Storage.Frame_Operations;
