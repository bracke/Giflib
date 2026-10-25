with Giflib.Errors;
with Giflib.Streams;

package body Giflib.Internal.Encoder_Storage.Quantization_Operations is
   function Quantize
     (Object : in out Resources;
      Source : Images.Image_View;
      Pixel_Count : Byte_Count;
      Output : out Giflib.Quantization.Quantization_Result;
      Options : Giflib.Quantization.Quantize_Options;
      Constraints : Limits.Limit_Set) return Results.Result
   is
      Outcome : Results.Result;
      procedure Run (Pixels : in out Streams.Byte_Array) is
      begin
         Outcome := Giflib.Quantization.Quantize
           (Object.Quantizer_Data,
            Source,
            Pixels (1 .. Natural (Pixel_Count)),
            Output,
            Options,
            Constraints);
      end Run;
   begin
      if Pixel_Count = 0
        or else Pixel_Count > Byte_Count (Natural'Last)
        or else Truecolor_Length (Object) < Pixel_Count
      then
         return Results.Failure
           (Errors.Make (Errors.Internal_Invariant_Failed));
      end if;
      Owned_Buffers.Update (Object.Truecolor_Buffer, Run'Access);
      return Outcome;
   end Quantize;

end Giflib.Internal.Encoder_Storage.Quantization_Operations;
