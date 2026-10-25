with Giflib.Animations;
with Giflib.Errors;
with Giflib.Frames;
with Giflib.Images;
with Giflib.Limits;
with Giflib.Metadata;
with Giflib.Palettes;
with Giflib.Results;
with Giflib.Streams;
with Giflib.Quantization;
private with Giflib.Internal.Encoder_Storage;
private with Giflib.Internal.Ownership;

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
   type Frame_Palette (Selection : Palette_Selection := Use_Global_Palette) is record
      case Selection is
         when Use_Global_Palette =>
            null;
         when Use_Local_Palette =>
            Value : Palettes.Palette;
      end case;
   end record;
   Global_Frame_Palette : constant Frame_Palette :=
     (Selection => Use_Global_Palette);
   subtype Encodable_Extension_Kind is Metadata.Encodable_Extension_Kind;
   subtype Extension_Descriptor is Metadata.Extension_Descriptor;
   Comment_Extension : constant Encodable_Extension_Kind :=
     Metadata.Comment_Extension;
   Plain_Text_Extension : constant Encodable_Extension_Kind :=
     Metadata.Plain_Text_Extension;
   Application_Extension : constant Encodable_Extension_Kind :=
     Metadata.Application_Extension;
   Unknown_Extension : constant Encodable_Extension_Kind :=
     Metadata.Unknown_Extension;
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
      Palette : Frame_Palette;
      Pixels : Streams.Byte_Array) return Results.Result;
   function Add_Extension
     (Object : in out Encoder;
      Descriptor : Extension_Descriptor;
      Payload : Streams.Byte_Array) return Results.Result;
   function Add_Extension_Exact
     (Object : in out Encoder;
      Descriptor : Extension_Descriptor;
      Payload : Streams.Byte_Array;
      Chunk_Lengths : Chunk_Length_Array) return Results.Result;

   --  Compatibility operations for decoded metadata.  Only Kind and Label are
   --  encoding inputs; the remaining observational fields are ignored.  Their
   --  distinct names keep descriptor aggregates unambiguous.
   function Add_Decoded_Extension
     (Object : in out Encoder;
      Info : Metadata.Extension_Info;
      Payload : Streams.Byte_Array) return Results.Result;
   function Add_Decoded_Extension_Exact
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
   subtype Encoder_Resources is Internal.Encoder_Storage.Resources;

   type Encoder
     (Output : not null access Streams.Destination'Class)
      is limited record
      Current_State : Encoder_State := Uninitialized;
      Options : Encode_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits;
      Screen : Screen_Info;
      Global_Palette : Palettes.Palette;
      Has_Global_Palette : Boolean := False;
      Loop_Data : Animations.Loop_Info := Animations.No_Loop;
      Header_Written : Boolean := False;
      Frames_Written : Frame_Ordinal := 0;
      Extensions_Written : Natural := 0;
      Bytes_Written : Byte_Count := 0;
      Compressed_Bytes_Written : Byte_Count := 0;
      Resources : Encoder_Resources;
      Diagnostic : Errors.Error := Errors.Make (Errors.No_Error);
      Allocation_Fault : aliased Internal.Ownership.Fault_State;
   end record;

   function Fail
     (Object : in out Encoder;
      Item : Errors.Error) return Results.Result;
   function Reject_Request
     (Object : Encoder;
      Item : Errors.Error) return Results.Result;
   function Reject_Frame_Request
     (Object : Encoder;
      Item : Errors.Error) return Results.Result;
   function Fail_Frame
     (Object : in out Encoder;
      Item : Errors.Error) return Results.Result;
   function Invalid_Transition (Object : Encoder) return Results.Result;
   function Has_Extension_Capacity
     (Object : Encoder;
      Additional : Natural) return Boolean;
   function Validate_Frame_Request
     (Object : Encoder;
      Info : Frame_Info) return Results.Result;
   function Write_Raw
     (Object : in out Encoder;
      Data : Streams.Byte_Array) return Results.Result;
   function Write_Header (Object : in out Encoder) return Results.Result;
   function Write_Palette
     (Object : in out Encoder;
      Palette : Palettes.Palette) return Results.Result;
end Giflib.Encoding;
