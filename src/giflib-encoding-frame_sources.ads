private package Giflib.Encoding.Frame_Sources
  with Preelaborate
is
   function Indexed_Length
     (Pixels : Streams.Byte_Array) return Byte_Count;

   function Encode_Indexed
     (Object : in out Encoder;
      Info : Frame_Info;
      Pixels : Streams.Byte_Array;
      Minimum : Byte;
      Maximum_Index : Byte;
      Compressed : out Byte_Count;
      Wire_Bytes : out Byte_Count) return Results.Result;

   function Stored_Length (Pixel_Count : Byte_Count) return Byte_Count;

   function Encode_Stored
     (Object : in out Encoder;
      Info : Frame_Info;
      Pixel_Count : Byte_Count;
      Minimum : Byte;
      Maximum_Index : Byte;
      Compressed : out Byte_Count;
      Wire_Bytes : out Byte_Count) return Results.Result;
end Giflib.Encoding.Frame_Sources;
