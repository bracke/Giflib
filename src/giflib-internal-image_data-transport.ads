with Giflib.Internal.Blocks;

private package Giflib.Internal.Image_Data.Transport with Preelaborate is
   generic
      with function Consume
        (Object : in out Streams.Source'Class;
         Reader : in out Blocks.Sub_Block_Reader;
         Minimum_Code_Size : Byte) return Results.Result;
   function Process
     (Object : in out Streams.Source'Class;
      Constraints : Limits.Limit_Set;
      Total_Compressed_Bytes : in out Byte_Count;
      Frame : Frame_Ordinal) return Results.Result;
end Giflib.Internal.Image_Data.Transport;
