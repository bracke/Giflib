private package Giflib.Encoding.Frame_Preparation
  with Preelaborate
is
   type Prepared_Frame_Request is record
      Effective : Palettes.Palette;
      Minimum : Byte := 2;
   end record;

   function Validate
     (Object : Encoder;
      Info : Frame_Info;
      Palette : Frame_Palette;
      Data : out Prepared_Frame_Request) return Results.Result;
end Giflib.Encoding.Frame_Preparation;
