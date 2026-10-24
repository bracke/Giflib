with Giflib.Errors;
with Giflib.Frames;
with Giflib.Images;
with Giflib.Limits;
with Giflib.Metadata;
with Giflib.Palettes;
with Giflib.Results;
with Giflib.Streams;
with Giflib.Quantization;
private with Giflib.Internal.LZW_Encoding;
private with Giflib.Internal.Ownership;
private with Giflib.Internal.Owned_Buffers;
private with Ada.Finalization;

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
   type Encoder
     (Output : not null access Streams.Destination'Class)
      is limited private;

   function Initialize
     (Object : in out Encoder;
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
   type Encoder_Resources is new Ada.Finalization.Limited_Controlled with record
      Truecolor_Pixels : Internal.Owned_Buffers.Handle;
      Allocation_Budget : aliased Internal.Ownership.Byte_Budget;
      Quantizer : Quantization.Workspace;
      LZW_Workspace : Internal.LZW_Encoding.Workspace_Handle;
      Cleanup_Failed : Boolean := False;
   end record;
   overriding procedure Finalize (Resources : in out Encoder_Resources);

   type Encoder
     (Output : not null access Streams.Destination'Class)
      is limited record
      Current_State : Encoder_State := Uninitialized;
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
      Resources : Encoder_Resources;
      Diagnostic : Errors.Error := Errors.Make (Errors.No_Error);
      Allocation_Fault : aliased Internal.Ownership.Fault_State;
   end record;

   function Fail
     (Object : in out Encoder;
      Item : Errors.Error) return Results.Result;
   function Invalid_Transition (Object : Encoder) return Results.Result;
   function Has_Extension_Capacity
     (Object : Encoder;
      Additional : Natural) return Boolean;
   function Write_Raw
     (Object : in out Encoder;
      Data : Streams.Byte_Array) return Results.Result;
   function Write_Header (Object : in out Encoder) return Results.Result;
   function Output_Position
     (Object : Encoder) return Streams.Destination_Position_Result;
end Giflib.Encoding;
