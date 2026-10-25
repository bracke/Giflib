with Giflib.Errors;
with Giflib.Animations;
with Giflib.Frames;
with Giflib.Limits;
with Giflib.Metadata;
with Giflib.Results;
with Giflib.Streams;

private with Giflib.Internal.Metadata_Store;
private with Giflib.Internal.LZW;
private with Giflib.Internal.Ownership;
private with Giflib.Internal.Owned_Buffers;
private with Giflib.Palettes;
private with Ada.Finalization;

package Giflib.Decoding is
   pragma Preelaborate;

   type Decoder_State is
     (Uninitialized,
      Initialized,
      Header_Ready,
      Awaiting_Frame_Decision,
      Decoding_Frame,
      Completed,
      Cancelled,
      Failed,
      Finalized);

   type Output_Mode is (Raw_Indexed, Expanded_Frame, Composited_RGBA);

   type Decode_Options is record
      Mode : Output_Mode := Raw_Indexed;
      Strictness : Strictness_Mode := Strict;
      Retention : Metadata.Retention_Policy := Metadata.Parse_Known_Without_Retention;
   end record;

   Default_Options : constant Decode_Options := (others => <>);

   subtype Header_Info is Animations.Screen_Info;
   subtype Frame_Info is Frames.Indexed_Frame_Info;

   type Event_Kind is (Image_Event, Extension_Event, End_Event);
   type Decode_Event (Kind : Event_Kind := End_Event) is record
      Offset : Source_Offset := 0;
      case Kind is
         when Image_Event =>
            Frame : Frame_Ordinal := 0;
            Left : Coordinate := 0;
            Top : Coordinate := 0;
            Width : Image_Width := Image_Width'First;
            Height : Image_Height := Image_Height'First;
            Interlaced : Boolean := False;
            Indexed_Bytes : Byte_Count := 1;
            Expanded_Bytes : Byte_Count := 4;
         when Extension_Event =>
            Extension : Metadata.Extension_Info;
         when End_Event =>
            null;
      end case;
   end record;

   type Decoder
     (Input : not null access Streams.Source'Class)
      is limited private;

   function Initialize
     (Object : in out Decoder;
      Options : Decode_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits) return Results.Result;

   function Reset
     (Object : in out Decoder;
      Options : Decode_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits) return Results.Result;

   function Read_Header
     (Object : in out Decoder;
      Header : out Header_Info) return Results.Result;

   function Next_Event
     (Object : in out Decoder;
      Event : out Decode_Event) return Results.Result;

   function Decode_Indexed_Frame
     (Object : in out Decoder;
      Target : out Streams.Byte_Array;
      Info : out Frame_Info) return Results.Result;

   --  Expands the frame rectangle (not the logical canvas) to row-major RGBA.
   --  Transparent pixels retain their palette RGB value with alpha zero.
   function Decode_Expanded_Frame
     (Object : in out Decoder;
      Target : out Streams.Byte_Array;
      Info : out Frame_Info) return Results.Result;

   function Decode_Composited_Frame
     (Object : in out Decoder;
      Target : out Streams.Byte_Array;
      Info : out Frame_Info) return Results.Result;

   function Skip_Frame (Object : in out Decoder) return Results.Result;
   function Cancel (Object : in out Decoder) return Results.Result;
   function State (Object : Decoder) return Decoder_State;
   function First_Error (Object : Decoder) return Errors.Error;
   function Warning_Count (Object : Decoder) return Natural;
   function Warning_At
     (Object : Decoder;
      Index : Positive;
      Item : out Errors.Warning) return Results.Result;
   function Looping (Object : Decoder) return Animations.Loop_Info;
   function Retained_Extension_Count (Object : Decoder) return Natural;
   function Retained_Extension_Info
     (Object : Decoder;
      Index : Positive;
      Info : out Metadata.Extension_Info) return Results.Result;
   function Copy_Retained_Extension_Payload
     (Object : Decoder;
      Index : Positive;
      Target : out Streams.Byte_Array;
      Count : out Byte_Count) return Results.Result;
   function Retained_Extension_Chunk_Count
     (Object : Decoder;
      Index : Positive;
      Count : out Natural) return Results.Result;
   function Copy_Retained_Extension_Chunk
     (Object : Decoder;
      Index : Positive;
      Chunk_Index : Positive;
      Target : out Streams.Byte_Array;
      Count : out Byte_Count) return Results.Result;
   procedure Finalize (Object : in out Decoder);

private
   type Prepared_Frame is record
      Left : Coordinate := 0;
      Top : Coordinate := 0;
      Width : Image_Width := Image_Width'First;
      Height : Image_Height := Image_Height'First;
      Has_Local_Palette : Boolean := False;
      Interlaced : Boolean := False;
      Local_Palette_Sorted : Boolean := False;
      Palette : Palettes.Palette;
      Control : Frames.Graphic_Control := Frames.Default_Control;
   end record;

   type Warning_Array is array (Positive range 1 .. 256) of Errors.Warning;
   type Decoder_Resources is new Ada.Finalization.Limited_Controlled with record
      Metadata_Storage : Internal.Metadata_Store.Store;
      Allocation_Budget : aliased Internal.Ownership.Byte_Budget;
      Canvas : Internal.Owned_Buffers.Handle;
      Snapshot : Internal.Owned_Buffers.Handle;
      Frame_Scratch : Internal.Owned_Buffers.Handle;
      LZW_Workspace : Internal.LZW.Workspace_Handle;
      Cleanup_Failed : Boolean := False;
   end record;
   overriding procedure Finalize (Object : in out Decoder_Resources);

   type Decoder
     (Input : not null access Streams.Source'Class)
      is limited record
      Current_State : Decoder_State := Uninitialized;
      Options : Decode_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits;
      Header_Data : Header_Info;
      Frames_Seen : Frame_Ordinal := 0;
      Total_Decoded_Pixels : Pixel_Count := 0;
      Total_Compressed_Bytes : Byte_Count := 0;
      Extensions_Seen : Natural := 0;
      Resources : Decoder_Resources;
      Pending_Control : Frames.Graphic_Control := Frames.Default_Control;
      Has_Pending_Control : Boolean := False;
      Pending_Frame : Prepared_Frame;
      Has_Pending_Frame : Boolean := False;
      Loop_Data : Animations.Loop_Info := Animations.No_Loop;
      Snapshot_Rectangle : Frames.Rectangle;
      Previous_Rectangle : Frames.Rectangle;
      Previous_Control : Frames.Graphic_Control := Frames.Default_Control;
      Has_Previous_Frame : Boolean := False;
      Warnings : Warning_Array;
      Stored_Warnings : Natural range 0 .. 256 := 0;
      Diagnostic : Errors.Error := Errors.Make (Errors.No_Error);
      Allocation_Fault : Internal.Ownership.Fault_State;
   end record;

   procedure Add_Warning
     (Object : in out Decoder;
      Code : Errors.Warning_Code;
      Severity : Errors.Warning_Severity;
      Context : Errors.Diagnostic_Context := (others => <>));
   function Input_Position
     (Object : Decoder) return Streams.Source_Position_Result;
end Giflib.Decoding;
