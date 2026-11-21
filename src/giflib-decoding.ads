with Giflib.Errors;
with Giflib.Animations;
with Giflib.Cleanup;
with Giflib.Frames;
with Giflib.Limits;
with Giflib.Metadata;
with Giflib.Results;
with Giflib.Streams;

private with Giflib.Internal.Decoder_Storage;
private with Giflib.Internal.Ownership;
private with Giflib.Palettes;

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
   function State (Object : Decoder) return Decoder_State;

   function Initialize
     (Object : in out Decoder;
      Options : Decode_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits) return Results.Result
     with Post =>
       (if Results.Succeeded (Initialize'Result)
        then State (Object) = Initialized);

   function Reset
     (Object : in out Decoder;
      Options : Decode_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits) return Results.Result
     with Post =>
       (if Results.Succeeded (Reset'Result)
        then State (Object) = Initialized);

   function Read_Header
     (Object : in out Decoder;
      Header : out Header_Info) return Results.Result
     with Post =>
       (if Results.Succeeded (Read_Header'Result)
        then State (Object) = Header_Ready);

   function Next_Event
     (Object : in out Decoder;
      Event : out Decode_Event) return Results.Result
     with Post =>
       (if Results.Succeeded (Next_Event'Result)
        then State (Object) =
          (case Event.Kind is
              when Image_Event => Awaiting_Frame_Decision,
              when Extension_Event => Header_Ready,
              when End_Event => Completed));

   function Decode_Indexed_Frame
     (Object : in out Decoder;
      Target : out Streams.Byte_Array;
      Info : out Frame_Info) return Results.Result
     with Post =>
       (if Results.Succeeded (Decode_Indexed_Frame'Result)
        then State (Object) = Header_Ready);

   --  Expands the frame rectangle (not the logical canvas) to row-major RGBA.
   --  Transparent pixels retain their palette RGB value with alpha zero.
   function Decode_Expanded_Frame
     (Object : in out Decoder;
      Target : out Streams.Byte_Array;
      Info : out Frame_Info) return Results.Result
     with Post =>
       (if Results.Succeeded (Decode_Expanded_Frame'Result)
        then State (Object) = Header_Ready);

   function Decode_Composited_Frame
     (Object : in out Decoder;
      Target : out Streams.Byte_Array;
      Info : out Frame_Info) return Results.Result
     with Post =>
       (if Results.Succeeded (Decode_Composited_Frame'Result)
        then State (Object) = Header_Ready);

   function Skip_Frame (Object : in out Decoder) return Results.Result
     with Post =>
       (if Results.Succeeded (Skip_Frame'Result)
        then State (Object) = Header_Ready);
   function Cancel (Object : in out Decoder) return Results.Result
     with Post =>
       (if Results.Succeeded (Cancel'Result)
        then State (Object) = Cancelled);
   function First_Error (Object : Decoder) return Errors.Error;
   function First_Cleanup_Status
     (Object : Decoder) return Cleanup.Cleanup_Status;
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
   type Prepared_Frame (Present : Boolean := False) is record
      case Present is
         when True =>
            Left : Coordinate := 0;
            Top : Coordinate := 0;
            Width : Image_Width := Image_Width'First;
            Height : Image_Height := Image_Height'First;
            Has_Local_Palette : Boolean := False;
            Interlaced : Boolean := False;
            Local_Palette_Sorted : Boolean := False;
            Palette : Palettes.Palette;
            Control : Frames.Graphic_Control := Frames.Default_Control;
         when False =>
            null;
      end case;
   end record;
   type Optional_Control (Present : Boolean := False) is record
      case Present is
         when True =>
            Value : Frames.Graphic_Control := Frames.Default_Control;
         when False =>
            null;
      end case;
   end record;
   type Previous_Frame_State (Present : Boolean := False) is record
      case Present is
         when True =>
            Rectangle : Frames.Rectangle;
            Control : Frames.Graphic_Control := Frames.Default_Control;
            Snapshot_Rectangle : Frames.Rectangle;
         when False =>
            null;
      end case;
   end record;

   type Warning_Array is
     array (Positive range 1 .. Limits.Maximum_Warning_Records)
       of Errors.Warning;
   subtype Decoder_Resources is Internal.Decoder_Storage.Resources;

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
      Pending_Control : Optional_Control;
      Pending_Frame : Prepared_Frame;
      Loop_Data : Animations.Loop_Info := Animations.No_Loop;
      Previous_Frame : Previous_Frame_State;
      Warnings : Warning_Array;
      Stored_Warnings : Limits.Warning_Record_Limit := 0;
      Diagnostic : Errors.Error := Errors.No_Error_Value;
      Resources : Decoder_Resources;
      Allocation_Fault : Internal.Ownership.Fault_State;
   end record;

end Giflib.Decoding;
