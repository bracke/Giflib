private package Giflib.Decoding.Session_Transitions
  with Preelaborate
is
   use type Header_Info;
   use type Frames.Graphic_Control;

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
end Giflib.Decoding.Session_Transitions;
