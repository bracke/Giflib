package body Giflib.Decoding.Session_Arithmetic
  with SPARK_Mode
is
   procedure Commit_Header
     (Object : in out Header_Transition_State;
      Header : Header_Info) is
   begin
      Object.Header_Data := Header;
      Object.Current_State := Header_Ready;
   end Commit_Header;

   procedure Complete_Frame (Object : in out Frame_Transition_State) is
   begin
      Object.Pending_Control := Frames.Default_Control;
      Object.Has_Pending_Control := False;
      Object.Has_Pending_Frame := False;
      Object.Frames_Seen := Object.Frames_Seen + 1;
      Object.Current_State := Header_Ready;
   end Complete_Frame;
end Giflib.Decoding.Session_Arithmetic;
