with Giflib.Internal.Container;
with Giflib.Internal.LZW;
with Giflib.Limits;
with Giflib.Palettes;
with Giflib.Results;
with Giflib.Streams;

package Giflib.Internal.Image_Data is
   pragma Preelaborate;

   function Decode_Indices
     (Context : in out LZW.Workspace_Handle;
      Object : in out Streams.Source'Class;
      Descriptor : Container.Image_Descriptor;
      Palette : Palettes.Palette;
      Constraints : Limits.Limit_Set;
      Total_Decoded_Pixels : in out Pixel_Count;
      Total_Compressed_Bytes : in out Byte_Count;
      Output : out Streams.Byte_Array;
      Frame : Frame_Ordinal := 0) return Results.Result;
end Giflib.Internal.Image_Data;
