private package Giflib.Decoding.Session_Arithmetic
  with Preelaborate, SPARK_Mode
is
   use type Header_Info;
   use type Frames.Graphic_Control;

   type Header_Transition_State is record
      Current_State : Decoder_State := Uninitialized;
      Header_Data : Header_Info;
   end record;

   procedure Commit_Header
     (Object : in out Header_Transition_State;
      Header : Header_Info)
     with Pre => Object.Current_State = Initialized,
          Post => Object.Current_State = Header_Ready
                  and then Object.Header_Data = Header;

   type Frame_Transition_State is record
      Current_State : Decoder_State := Uninitialized;
      Has_Pending_Control : Boolean := False;
      Has_Pending_Frame : Boolean := False;
      Frames_Seen : Frame_Ordinal := 0;
      Pending_Control : Frames.Graphic_Control := Frames.Default_Control;
   end record;

   procedure Complete_Frame (Object : in out Frame_Transition_State)
     with Pre => Object.Current_State = Decoding_Frame
                 and then Object.Has_Pending_Frame
                 and then Object.Frames_Seen < Frame_Ordinal'Last,
          Post => Object.Current_State = Header_Ready
                  and then not Object.Has_Pending_Frame
                  and then not Object.Has_Pending_Control
                  and then Object.Pending_Control = Frames.Default_Control
                  and then Object.Frames_Seen = Object.Frames_Seen'Old + 1;
end Giflib.Decoding.Session_Arithmetic;
