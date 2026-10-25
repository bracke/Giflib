private package Giflib.Encoding.Frame_Pipeline
  with Preelaborate
is
   function Add_Indexed
     (Object : in out Encoder;
      Info : Frame_Info;
      Palette : Frame_Palette;
      Pixels : Streams.Byte_Array) return Results.Result;

   function Add_Stored
     (Object : in out Encoder;
      Info : Frame_Info;
      Palette : Frame_Palette;
      Pixel_Count : Byte_Count) return Results.Result;
end Giflib.Encoding.Frame_Pipeline;
