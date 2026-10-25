with Giflib.Decoding.State_Arithmetic;

private package Giflib.Decoding.Session_Transitions
  with Preelaborate
is
   use type Header_Info;
   use type Animations.Loop_Info;
   use type Errors.Error_Code;
   use type Frames.Graphic_Control;
   use type Frames.Rectangle;
   use type Limits.Limit_Set;

   function Session_Data_Is_Reset (Object : Decoder) return Boolean is
     (Object.Header_Data = Header_Info'(others => <>)
      and then Object.Frames_Seen = 0
      and then Object.Total_Decoded_Pixels = 0
      and then Object.Total_Compressed_Bytes = 0
      and then Object.Extensions_Seen = 0
      and then Object.Pending_Control = Frames.Default_Control
      and then not Object.Has_Pending_Control
      and then Object.Pending_Frame = Prepared_Frame'(others => <>)
      and then not Object.Has_Pending_Frame
      and then Object.Loop_Data = Animations.No_Loop
      and then Object.Snapshot_Rectangle = Frames.Rectangle'(others => <>)
      and then Object.Previous_Rectangle = Frames.Rectangle'(others => <>)
      and then Object.Previous_Control = Frames.Default_Control
      and then not Object.Has_Previous_Frame
      and then Object.Stored_Warnings = 0);

   procedure Begin_Session
     (Object : in out Decoder;
      Options : Decode_Options;
      Constraints : Limits.Limit_Set)
     with Pre => State_Arithmetic.Can_Initialize (Object.Current_State),
          Post => Object.Current_State = Initialized
                  and then Object.Options = Options
                  and then Object.Constraints = Constraints
                  and then Session_Data_Is_Reset (Object)
                  and then Object.Diagnostic.Code = Errors.No_Error;

   procedure Commit_Header
     (Object : in out Decoder;
      Header : Header_Info)
     with Pre => Object.Current_State = Initialized,
          Post => Object.Current_State = Header_Ready
                  and then Object.Header_Data = Header;

   procedure Fail_Session (Object : in out Decoder)
     with Post => Object.Current_State = Failed;

   procedure Reset_Session (Object : in out Decoder)
     with Post => Object.Current_State = Uninitialized
                  and then Object.Diagnostic.Code = Errors.No_Error;

   procedure Discover_Frame (Object : in out Decoder)
     with Pre => Object.Current_State = Header_Ready,
          Post => Object.Current_State = Decoding_Frame;

   procedure Await_Frame_Decision (Object : in out Decoder)
     with Pre => Object.Current_State = Decoding_Frame,
          Post => Object.Current_State = Awaiting_Frame_Decision
                  and then Object.Has_Pending_Frame;

   procedure Begin_Frame (Object : in out Decoder)
     with Pre => Object.Current_State = Awaiting_Frame_Decision,
          Post => Object.Current_State = Decoding_Frame;

   procedure Record_Extension (Object : in out Decoder)
     with Pre => Object.Extensions_Seen < Natural'Last,
          Post => Object.Extensions_Seen = Object.Extensions_Seen'Old + 1;

   procedure Set_Pending_Control
     (Object : in out Decoder;
      Control : Frames.Graphic_Control)
     with Post => Object.Pending_Control = Control
                  and then Object.Has_Pending_Control;

   procedure Clear_Pending_Control (Object : in out Decoder)
     with Post => Object.Pending_Control = Frames.Default_Control
                  and then not Object.Has_Pending_Control;

   procedure Set_Loop
     (Object : in out Decoder;
      Looping : Animations.Loop_Info)
     with Post => Object.Loop_Data = Looping;

   procedure Record_Compressed_Bytes
     (Object : in out Decoder;
      Count : Byte_Count)
     with Pre => Object.Total_Compressed_Bytes <= Byte_Count'Last - Count,
          Post => Object.Total_Compressed_Bytes =
                    Object.Total_Compressed_Bytes'Old + Count;

   procedure Commit_Resource_Usage
     (Object : in out Decoder;
      Decoded_Pixels : Pixel_Count;
      Compressed_Bytes : Byte_Count)
     with Pre => Decoded_Pixels >= Object.Total_Decoded_Pixels
                 and then Compressed_Bytes >= Object.Total_Compressed_Bytes,
          Post => Object.Total_Decoded_Pixels = Decoded_Pixels
                  and then Object.Total_Compressed_Bytes = Compressed_Bytes;

   procedure Complete_Stream (Object : in out Decoder)
     with Pre => Object.Current_State = Header_Ready,
          Post => Object.Current_State = Completed;

   procedure Cancel_Session (Object : in out Decoder)
     with Pre => State_Arithmetic.Can_Cancel (Object.Current_State),
          Post => Object.Current_State = Cancelled
                  and then Object.Diagnostic.Code = Errors.Operation_Cancelled;

   procedure Complete_Frame (Object : in out Decoder)
     with Pre => Object.Current_State = Decoding_Frame
                 and then Object.Has_Pending_Frame
                 and then Object.Frames_Seen < Frame_Ordinal'Last,
          Post => Object.Current_State = Header_Ready
                  and then not Object.Has_Pending_Frame
                  and then not Object.Has_Pending_Control
                  and then Object.Pending_Control = Frames.Default_Control
                  and then Object.Frames_Seen = Object.Frames_Seen'Old + 1;

   procedure Finalize_Session (Object : in out Decoder)
     with Post => Object.Current_State = Finalized
                  and then Session_Data_Is_Reset (Object);
end Giflib.Decoding.Session_Transitions;
