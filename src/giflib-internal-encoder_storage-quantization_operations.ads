with Giflib.Images;
with Giflib.Limits;
with Giflib.Results;
with Giflib.Streams;

package Giflib.Internal.Encoder_Storage.Quantization_Operations is
   pragma Preelaborate;

   function Quantize
     (Object : in out Resources;
      Source : Images.Image_View;
      Pixel_Count : Byte_Count;
      Output : out Giflib.Quantization.Quantization_Result;
      Options : Giflib.Quantization.Quantize_Options;
      Constraints : Limits.Limit_Set) return Results.Result;

   generic
      with function Consume
        (Pixels : Streams.Byte_Array) return Results.Result;
   function Consume_Truecolor_Pixels
     (Object : in out Resources;
      Pixel_Count : Byte_Count) return Results.Result;
end Giflib.Internal.Encoder_Storage.Quantization_Operations;
