with Giflib.Internal.Blocks;
with Giflib.Internal.Interlacing;
with Giflib.Results;
with Giflib.Streams;

package Giflib.Internal.LZW.Testing is
   type Workspace is limited private;

   function Decode
     (Context : in out Workspace;
      Object : in out Streams.Source'Class;
      Blocks_Reader : in out Blocks.Sub_Block_Reader;
      Minimum_Code_Size : Byte;
      Output : out Streams.Byte_Array;
      Decoded_Count : out Byte_Count;
      Max_Work : Byte_Count;
      Frame : Frame_Ordinal := 0;
      Maximum_Index : Byte := 255;
      Layout : Interlacing.Traversal_Layout :=
        Interlacing.Sequential_Layout) return Results.Result;

private
   type Workspace is limited record
      Value : Giflib.Internal.LZW.Workspace;
   end record;
end Giflib.Internal.LZW.Testing;
