with Giflib;
with Giflib.Capabilities;
with Giflib.Decoding;
with Giflib.Errors;
with Giflib.Encoding;
with Giflib.Images;
with Giflib.Optimization;
with Giflib.Quantization;
with Giflib.Limits;
with Giflib.Results;
with Giflib.Streams;
with Giflib.Version;

package Giflib_API_Consumer is
   Version : constant String := Giflib.Version.Current;
   Default_Mode : constant Giflib.Strictness_Mode := Giflib.Strict;
   Default_Limits : constant Giflib.Limits.Limit_Set := Giflib.Limits.Default_Limits;
   No_Error : constant Giflib.Errors.Error := Giflib.Errors.Make (Giflib.Errors.No_Error);
   Success : constant Giflib.Results.Result := Giflib.Results.Success;
   Streams_Available : constant Boolean := Giflib.Capabilities.Memory_Streams;
   subtype Decoder_State is Giflib.Decoding.Decoder_State;
   subtype Encoder_State is Giflib.Encoding.Encoder_State;
   subtype Image_View is Giflib.Images.Image_View;
   subtype Quantize_Options is Giflib.Quantization.Quantize_Options;
   subtype Optimization_Action is Giflib.Optimization.Optimization_Action;
   subtype Byte_Vector is Giflib.Streams.Byte_Array;
end Giflib_API_Consumer;
