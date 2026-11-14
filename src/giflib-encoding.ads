with Giflib.Animations;
with Giflib.Cleanup;
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
      Header_Committed,
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
   function State (Object : Encoder) return Encoder_State;

   function Initialize
     (Object : in out Encoder;
      Options : Encode_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits) return Results.Result
     with Post =>
       (if Results.Succeeded (Initialize'Result)
        then State (Object) = Initialized);
   function Define_Screen (Object : in out Encoder; Screen : Screen_Info)
      return Results.Result
     with Post =>
       (if Results.Succeeded (Define_Screen'Result)
        then State (Object) = Screen_Defined);
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
      Pixels : Streams.Byte_Array) return Results.Result
     with Post =>
       (if Results.Succeeded (Add_Indexed_Frame'Result)
        then State (Object) = Accepting_Frames);
   function Add_Extension
     (Object : in out Encoder;
      Descriptor : Extension_Descriptor;
      Payload : Streams.Byte_Array) return Results.Result
     with Post =>
       (if Results.Succeeded (Add_Extension'Result)
        then State (Object) = Accepting_Frames);
   function Add_Extension_Exact
     (Object : in out Encoder;
      Descriptor : Extension_Descriptor;
      Payload : Streams.Byte_Array;
      Chunk_Lengths : Chunk_Length_Array) return Results.Result
     with Post =>
       (if Results.Succeeded (Add_Extension_Exact'Result)
        then State (Object) = Accepting_Frames);

   --  Compatibility operations for decoded metadata.  Only Kind and Label are
   --  encoding inputs; the remaining observational fields are ignored.  Their
   --  distinct names keep descriptor aggregates unambiguous.
   function Add_Decoded_Extension
     (Object : in out Encoder;
      Info : Metadata.Extension_Info;
      Payload : Streams.Byte_Array) return Results.Result
     with Post =>
       (if Results.Succeeded (Add_Decoded_Extension'Result)
        then State (Object) = Accepting_Frames);
   function Add_Decoded_Extension_Exact
     (Object : in out Encoder;
      Info : Metadata.Extension_Info;
      Payload : Streams.Byte_Array;
      Chunk_Lengths : Chunk_Length_Array) return Results.Result
     with Post =>
       (if Results.Succeeded (Add_Decoded_Extension_Exact'Result)
        then State (Object) = Accepting_Frames);
   function Add_Truecolor_Frame
     (Object : in out Encoder;
      Info : Frame_Info;
      Source : Images.Image_View;
      Options : Quantization.Quantize_Options := Quantization.Default_Options)
      return Results.Result
     with Post =>
       (if Results.Succeeded (Add_Truecolor_Frame'Result)
        then State (Object) = Accepting_Frames);
   function Finish (Object : in out Encoder) return Results.Result
     with Post =>
       (if Results.Succeeded (Finish'Result)
        then State (Object) = Completed);
   function Cancel (Object : in out Encoder) return Results.Result
     with Post =>
       (if Results.Succeeded (Cancel'Result)
        then State (Object) = Cancelled);
   function First_Error (Object : Encoder) return Errors.Error;
   function First_Cleanup_Status
     (Object : Encoder) return Cleanup.Cleanup_Status;
   procedure Finalize (Object : in out Encoder);

private
   subtype Encoder_Resources is Internal.Encoder_Storage.Resources;
   type Optional_Palette (Present : Boolean := False) is record
      case Present is
         when True =>
            Value : Palettes.Palette;
         when False =>
            null;
      end case;
   end record;

   type Encoder
     (Output : not null access Streams.Destination'Class)
      is limited record
      Current_State : Encoder_State := Uninitialized;
      Options : Encode_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits;
      Screen : Screen_Info;
      Global_Palette : Optional_Palette;
      Loop_Data : Animations.Loop_Info := Animations.No_Loop;
      Frames_Written : Frame_Ordinal := 0;
      Extensions_Written : Natural := 0;
      Bytes_Written : Byte_Count := 0;
      Compressed_Bytes_Written : Byte_Count := 0;
      Diagnostic : Errors.Error := Errors.Make (Errors.No_Error);
      Resources : Encoder_Resources;
      Quantizer_Data : Quantization.Workspace;
      Allocation_Fault : aliased Internal.Ownership.Fault_State;
   end record;

   function Write_Header (Object : in out Encoder) return Results.Result;
end Giflib.Encoding;
