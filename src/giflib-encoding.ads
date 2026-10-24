with Giflib.Errors;
with Giflib.Frames;
with Giflib.Images;
with Giflib.Limits;
with Giflib.Metadata;
with Giflib.Palettes;
with Giflib.Results;
with Giflib.Streams;
with Giflib.Quantization;

package Giflib.Encoding is
   pragma Preelaborate;

   type Encoder_State is
     (Uninitialized,
      Initialized,
      Screen_Defined,
      Accepting_Frames,
      Completed,
      Cancelled,
      Failed,
      Finalized);

   type Version_Selection is (Automatic_GIF89a, Force_GIF87a, Force_GIF89a);
   type Truecolor_Palette_Strategy is
     (Per_Frame_Local, Use_Existing_Global, Reuse_Identical_Global);

   type Encode_Options is record
      Version : Version_Selection := Automatic_GIF89a;
      Truecolor_Palettes : Truecolor_Palette_Strategy := Per_Frame_Local;
   end record;

   Default_Options : constant Encode_Options := (others => <>);

   type Screen_Info is record
      Width : Image_Width := Image_Width'First;
      Height : Image_Height := Image_Height'First;
      Color_Resolution : Positive range 1 .. 8 := 8;
      Background_Index : Palette_Index := 0;
      Pixel_Aspect_Ratio : Byte := 0;
   end record;

   type Frame_Info is record
      Left : Coordinate := 0;
      Top : Coordinate := 0;
      Width : Image_Width := Image_Width'First;
      Height : Image_Height := Image_Height'First;
      Interlaced : Boolean := False;
      Control : Frames.Graphic_Control := Frames.Default_Control;
   end record;

   type Palette_Selection is (Use_Global_Palette, Use_Local_Palette);
   type Chunk_Length_Array is array (Positive range <>) of Natural range 1 .. 255;
   type Destination_Access is access all Streams.Destination'Class;
   type Encoder is limited private;

   function Initialize
     (Object : in out Encoder;
      Output : not null Destination_Access;
      Options : Encode_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits) return Results.Result;
   function Define_Screen (Object : in out Encoder; Screen : Screen_Info) return Results.Result;
   function Set_Global_Palette
     (Object : in out Encoder;
      Palette : Palettes.Palette) return Results.Result;
   function Set_Loop_Count
     (Object : in out Encoder;
      Count : Natural) return Results.Result;
   function Add_Indexed_Frame
     (Object : in out Encoder;
      Info : Frame_Info;
      Selection : Palette_Selection;
      Local_Palette : Palettes.Palette;
      Pixels : Streams.Byte_Array) return Results.Result;
   function Add_Extension
     (Object : in out Encoder;
      Info : Metadata.Extension_Info;
      Payload : Streams.Byte_Array) return Results.Result;
   function Add_Extension_Exact
     (Object : in out Encoder;
      Info : Metadata.Extension_Info;
      Payload : Streams.Byte_Array;
      Chunk_Lengths : Chunk_Length_Array) return Results.Result;
   function Add_Truecolor_Frame
     (Object : in out Encoder;
      Info : Frame_Info;
      Source : Images.Image_View;
      Options : Quantization.Quantize_Options := Quantization.Default_Options) return Results.Result;
   function Finish (Object : in out Encoder) return Results.Result;
   function Cancel (Object : in out Encoder) return Results.Result;
   function State (Object : Encoder) return Encoder_State;
   function First_Error (Object : Encoder) return Errors.Error;
   procedure Finalize (Object : in out Encoder);

private
   type Encoder is limited record
      Current_State : Encoder_State := Uninitialized;
      Output : Destination_Access := null;
      Options : Encode_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits;
      Screen : Screen_Info;
      Global_Palette : Palettes.Palette;
      Has_Global_Palette : Boolean := False;
      Has_Loop : Boolean := False;
      Loop_Count : Natural range 0 .. 65_535 := 0;
      Header_Written : Boolean := False;
      Frames_Written : Frame_Ordinal := 0;
      Extensions_Written : Natural := 0;
      Start_Offset : Destination_Offset := 0;
      Bytes_Written : Byte_Count := 0;
      Compressed_Bytes_Written : Byte_Count := 0;
      Diagnostic : Errors.Error := Errors.Make (Errors.No_Error);
   end record;
end Giflib.Encoding;
