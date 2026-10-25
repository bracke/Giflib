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
