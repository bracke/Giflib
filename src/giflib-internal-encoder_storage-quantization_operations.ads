with Giflib.Images;
with Giflib.Limits;
with Giflib.Results;

package Giflib.Internal.Encoder_Storage.Quantization_Operations is
   pragma Preelaborate;

   function Quantize
     (Object : in out Resources;
      Source : Images.Image_View;
      Pixel_Count : Byte_Count;
      Output : out Giflib.Quantization.Quantization_Result;
      Options : Giflib.Quantization.Quantize_Options;
      Constraints : Limits.Limit_Set) return Results.Result;

end Giflib.Internal.Encoder_Storage.Quantization_Operations;
