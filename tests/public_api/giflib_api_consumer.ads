with Giflib;
with Giflib.Animations;
with Giflib.Capabilities;
with Giflib.Decoding;
with Giflib.Errors;
with Giflib.Encoding;
with Giflib.Images;
with Giflib.Frames;
with Giflib.Metadata;
with Giflib.Optimization;
with Giflib.Palettes;
with Giflib.Quantization;
with Giflib.Limits;
with Giflib.Results;
with Giflib.Streams;
with Giflib.Version;

package Giflib_API_Consumer is
   Version : constant String := Giflib.Version.Current;
   Default_Mode : constant Giflib.Strictness_Mode := Giflib.Strict;
   Default_Limits : constant Giflib.Limits.Limit_Set := Giflib.Limits.Default_Limits;
   subtype Warning_Record_Limit is Giflib.Limits.Warning_Record_Limit;
   Warning_Capacity : constant Warning_Record_Limit :=
     Giflib.Limits.Maximum_Warning_Records;
   No_Error : constant Giflib.Errors.Error := Giflib.Errors.Make (Giflib.Errors.No_Error);
   Success : constant Giflib.Results.Result := Giflib.Results.Success;
   Streams_Available : constant Boolean := Giflib.Capabilities.Memory_Streams;
   subtype Decoder_State is Giflib.Decoding.Decoder_State;
   subtype Encoder_State is Giflib.Encoding.Encoder_State;
   subtype Loop_Info is Giflib.Animations.Loop_Info;
   Global_Screen : constant Giflib.Animations.Screen_Info :=
     (Has_Global_Palette => True,
      Global_Palette => (Length => 2, others => <>),
      Global_Palette_Sorted => False,
      others => <>);
   subtype Frame_Rectangle is Giflib.Frames.Rectangle;
   subtype Image_View is Giflib.Images.Image_View;
   subtype Extension_Info is Giflib.Metadata.Extension_Info;
   subtype Encodable_Extension_Kind is Giflib.Encoding.Encodable_Extension_Kind;
   subtype Extension_Descriptor is Giflib.Encoding.Extension_Descriptor;
   Metadata_Descriptor : constant Giflib.Metadata.Extension_Descriptor :=
     (Kind => Giflib.Metadata.Comment_Extension);
   Shared_Descriptor : constant Extension_Descriptor := Metadata_Descriptor;
   subtype Palette is Giflib.Palettes.Palette;
   subtype Quantize_Options is Giflib.Quantization.Quantize_Options;
   Fixed_Quantization : constant Quantize_Options :=
     (Dither => Giflib.Quantization.No_Dither,
      Palette =>
        (Strategy => Giflib.Quantization.Use_Fixed_Palette,
         Fixed_Palette => (Length => 2, others => <>),
         Fixed_Transparent_Index => 0),
      Transparency => (Enabled => False));
   Quantized : constant Giflib.Quantization.Quantization_Result :=
     (Palette => (Length => 2, others => <>),
      Transparency => (Present => True, Index => 0));
   Prepared_Image : constant Giflib.Decoding.Decode_Event :=
     (Kind => Giflib.Decoding.Image_Event,
      Offset => 0,
      Frame => 0,
      Left => 0,
      Top => 0,
      Width => 1,
      Height => 1,
      Interlaced => False,
      Indexed_Bytes => 1,
      Expanded_Bytes => 4);
   subtype Optimization_Action is Giflib.Optimization.Optimization_Action;
   Transparent_Control : constant Giflib.Frames.Graphic_Control :=
     (Has_Transparency => True,
      Transparent_Index => 0,
      others => <>);
   Local_Frame_Palette : constant Giflib.Encoding.Frame_Palette :=
     (Selection => Giflib.Encoding.Use_Local_Palette,
      Value => (Length => 2, others => <>));
   Trimmed_Frame : constant Giflib.Optimization.Frame_Analysis :=
     (Action => Giflib.Optimization.Trim_To_Rectangle,
      Left => 0,
      Top => 0,
      Width => 1,
      Height => 1,
      Requires_Transparency => False);
   subtype Byte_Vector is Giflib.Streams.Byte_Array;
end Giflib_API_Consumer;
