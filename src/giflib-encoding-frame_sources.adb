with Giflib.Internal.Encoder_Storage.Frame_Operations;
with Giflib.Internal.Interlacing;

package body Giflib.Encoding.Frame_Sources is
   function Indexed_Length
     (Pixels : Streams.Byte_Array) return Byte_Count is
     (Byte_Count (Pixels'Length));

   function Encode_Indexed
     (Object : in out Encoder;
      Info : Frame_Info;
      Pixels : Streams.Byte_Array;
      Minimum : Byte;
      Maximum_Index : Byte;
      Compressed : out Byte_Count;
      Wire_Bytes : out Byte_Count) return Results.Result is
     (Internal.Encoder_Storage.Frame_Operations.Encode_LZW
        (Object.Resources, Object.Output.all, Pixels, Minimum,
         Object.Constraints.Max_LZW_Work,
         Object.Constraints.Max_Compressed_Bytes
           - Object.Compressed_Bytes_Written,
         Object.Constraints.Max_Output_Bytes - Object.Bytes_Written,
         Compressed, Wire_Bytes,
         Maximum_Index => Maximum_Index,
         Layout =>
           (if Info.Interlaced
            then (Is_Interlaced => True,
                  Width => Natural (Info.Width),
                  Height => Natural (Info.Height))
            else Internal.Interlacing.Sequential_Layout)));

   function Stored_Length (Pixel_Count : Byte_Count) return Byte_Count is
     (Pixel_Count);

   function Encode_Stored
     (Object : in out Encoder;
      Info : Frame_Info;
      Pixel_Count : Byte_Count;
      Minimum : Byte;
      Maximum_Index : Byte;
      Compressed : out Byte_Count;
      Wire_Bytes : out Byte_Count) return Results.Result is
     (Internal.Encoder_Storage.Frame_Operations.Encode_Stored_LZW
        (Object.Resources, Object.Output.all, Pixel_Count, Minimum,
         Object.Constraints.Max_LZW_Work,
         Object.Constraints.Max_Compressed_Bytes
           - Object.Compressed_Bytes_Written,
         Object.Constraints.Max_Output_Bytes - Object.Bytes_Written,
         Compressed, Wire_Bytes,
         Maximum_Index => Maximum_Index,
         Layout =>
           (if Info.Interlaced
            then (Is_Interlaced => True,
                  Width => Natural (Info.Width),
                  Height => Natural (Info.Height))
            else Internal.Interlacing.Sequential_Layout)));
end Giflib.Encoding.Frame_Sources;
