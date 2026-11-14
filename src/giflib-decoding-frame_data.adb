with Giflib.Internal.Decoder_Storage.Image_Operations;
with Giflib.Internal.Image_Data;

package body Giflib.Decoding.Frame_Data is
   function Decode_Indices
     (Object : in out Decoder;
      Output : out Streams.Byte_Array;
      Decoded_Pixels : in out Pixel_Count;
      Compressed_Bytes : in out Byte_Count) return Results.Result is
   begin
      return Internal.Decoder_Storage.Image_Operations.Decode_Indices
        (Object.Resources, Object.Input.all,
         Object.Pending_Frame.Width, Object.Pending_Frame.Height,
         Object.Pending_Frame.Interlaced, Object.Pending_Frame.Palette,
         Object.Constraints,
         Decoded_Pixels, Compressed_Bytes, Output, Object.Frames_Seen);
   end Decode_Indices;

   function Decode_Scratch
     (Object : in out Decoder;
      Pixel_Bytes : Byte_Count;
      Decoded_Pixels : in out Pixel_Count;
      Compressed_Bytes : in out Byte_Count) return Results.Result is
   begin
      return Internal.Decoder_Storage.Image_Operations.Decode_Frame_Scratch
        (Object.Resources, Object.Input.all,
         Object.Pending_Frame.Width, Object.Pending_Frame.Height,
         Object.Pending_Frame.Interlaced, Object.Pending_Frame.Palette,
         Object.Constraints,
         Decoded_Pixels, Compressed_Bytes, Pixel_Bytes, Object.Frames_Seen);
   end Decode_Scratch;

   function Skip
     (Object : in out Decoder;
      Compressed_Bytes : in out Byte_Count) return Results.Result
   is
   begin
      return Internal.Image_Data.Skip
        (Object.Input.all, Object.Constraints, Compressed_Bytes,
         Object.Frames_Seen);
   end Skip;
end Giflib.Decoding.Frame_Data;
