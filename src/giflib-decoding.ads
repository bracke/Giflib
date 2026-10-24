with Giflib.Errors;
with Giflib.Animations;
with Giflib.Frames;
with Giflib.Limits;
with Giflib.Metadata;
with Giflib.Results;
with Giflib.Streams;

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
   type Decode_Event is record
      Kind : Event_Kind := End_Event;
      Offset : Source_Offset := 0;
      Frame : Frame_Ordinal := 0;
      Extension_Label : Byte := 0;
      Extension : Metadata.Extension_Info;
   end record;

   type Source_Access is access all Streams.Source'Class;
   type Decoder is limited private;

   function Initialize
     (Object : in out Decoder;
      Input : not null Source_Access;
      Options : Decode_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits) return Results.Result;

   function Reset
     (Object : in out Decoder;
      Input : not null Source_Access;
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
   type Warning_Array is array (Positive range 1 .. 256) of Errors.Warning;
   type Payload_Chunk;
   type Payload_Chunk_Access is access Payload_Chunk;
   type Payload_Chunk is record
      Length : Natural range 1 .. 255 := 1;
      Data : Streams.Byte_Array (1 .. 255) := [others => 0];
      Next : Payload_Chunk_Access := null;
   end record;

   type Extension_Node;
   type Extension_Node_Access is access Extension_Node;
   type Extension_Node is record
      Info : Metadata.Extension_Info;
      First_Chunk : Payload_Chunk_Access := null;
      Last_Chunk : Payload_Chunk_Access := null;
      Next : Extension_Node_Access := null;
   end record;

   type Decoder is limited record
      Current_State : Decoder_State := Uninitialized;
      Input : Source_Access := null;
      Options : Decode_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits;
      Header_Data : Header_Info;
      Frames_Seen : Frame_Ordinal := 0;
      Total_Decoded_Pixels : Pixel_Count := 0;
      Total_Compressed_Bytes : Byte_Count := 0;
      Extensions_Seen : Natural := 0;
      Retained_First : Extension_Node_Access := null;
      Retained_Last : Extension_Node_Access := null;
      Retained_Count : Natural := 0;
      Retained_Bytes : Byte_Count := 0;
      Owned_Allocation_Bytes : Byte_Count := 0;
      Pending_Control : Frames.Graphic_Control := Frames.Default_Control;
      Has_Pending_Control : Boolean := False;
      Loop_Data : Animations.Loop_Info := Animations.No_Loop;
      Canvas : Streams.Byte_Array_Access := null;
      Snapshot : Streams.Byte_Array_Access := null;
      Snapshot_Rectangle : Frames.Rectangle;
      Previous_Rectangle : Frames.Rectangle;
      Previous_Control : Frames.Graphic_Control := Frames.Default_Control;
      Has_Previous_Frame : Boolean := False;
      Warnings : Warning_Array;
      Stored_Warnings : Natural range 0 .. 256 := 0;
      Diagnostic : Errors.Error := Errors.Make (Errors.No_Error);
   end record;
end Giflib.Decoding;
