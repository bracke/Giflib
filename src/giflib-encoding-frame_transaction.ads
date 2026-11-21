with Giflib.Encoding.Frame_Preparation;

private package Giflib.Encoding.Frame_Transaction
  with Preelaborate
is
   function Commit_Prefix
     (Object : in out Encoder;
      Info : Frame_Info;
      Palette : Frame_Palette;
      Data : Frame_Preparation.Prepared_Frame_Request)
      return Results.Result;

   function Complete
     (Object : in out Encoder;
      Outcome : Results.Result;
      Compressed : Byte_Count;
      Wire_Bytes : Byte_Count) return Results.Result;
end Giflib.Encoding.Frame_Transaction;
