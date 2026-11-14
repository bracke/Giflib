with Giflib.Internal.Geometry_Arithmetic;

private package Giflib.Decoding.Frame_Data
  with Preelaborate
is
   function Decode_Indices
     (Object : in out Decoder;
      Output : out Streams.Byte_Array;
      Decoded_Pixels : in out Pixel_Count;
      Compressed_Bytes : in out Byte_Count) return Results.Result
     with Pre => Object.Current_State = Decoding_Frame
                 and then Object.Pending_Frame.Present
                 and then Internal.Decoder_Storage.LZW_Allocated
                   (Object.Resources);

   function Decode_Scratch
     (Object : in out Decoder;
      Pixel_Bytes : Byte_Count;
      Decoded_Pixels : in out Pixel_Count;
      Compressed_Bytes : in out Byte_Count) return Results.Result
     with Pre => Object.Current_State = Decoding_Frame
                 and then Object.Pending_Frame.Present
                 and then Internal.Decoder_Storage.LZW_Allocated
                   (Object.Resources)
                 and then Internal.Decoder_Storage.Frame_Scratch_Allocated
                   (Object.Resources)
                 and then Pixel_Bytes = Internal.Geometry_Arithmetic.Area
                   (Object.Pending_Frame.Width, Object.Pending_Frame.Height)
                 and then Pixel_Bytes <= Byte_Count (Natural'Last)
                 and then Internal.Decoder_Storage.Frame_Scratch_Length
                   (Object.Resources) >= Pixel_Bytes;

   function Skip
     (Object : in out Decoder;
      Compressed_Bytes : in out Byte_Count) return Results.Result
     with Pre => Object.Current_State = Decoding_Frame
                 and then Object.Pending_Frame.Present;
end Giflib.Decoding.Frame_Data;
