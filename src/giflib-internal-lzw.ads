with Giflib.Internal.Blocks;
with Giflib.Results;
with Giflib.Streams;

package Giflib.Internal.LZW is
   pragma Preelaborate;

   function Decode
     (Object : in out Streams.Source'Class;
      Blocks_Reader : in out Blocks.Sub_Block_Reader;
      Minimum_Code_Size : Byte;
      Output : out Streams.Byte_Array;
      Decoded_Count : out Byte_Count;
      Max_Work : Byte_Count;
      Frame : Frame_Ordinal := 0;
      Interlace_Width : Natural := 0;
      Interlace_Height : Natural := 0) return Results.Result;
end Giflib.Internal.LZW;
