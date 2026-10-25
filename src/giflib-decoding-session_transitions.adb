with Giflib.Decoding.Session_Arithmetic;

package body Giflib.Decoding.Session_Transitions is
   procedure Commit_Header
     (Object : in out Decoder;
      Header : Header_Info) is
      Transition : Session_Arithmetic.Header_Transition_State :=
        (Current_State => Object.Current_State,
         Header_Data => Object.Header_Data);
   begin
      Session_Arithmetic.Commit_Header (Transition, Header);
      Object.Header_Data := Transition.Header_Data;
      Object.Current_State := Transition.Current_State;
   end Commit_Header;

   procedure Complete_Frame (Object : in out Decoder) is
      Transition : Session_Arithmetic.Frame_Transition_State :=
        (Current_State => Object.Current_State,
         Has_Pending_Control => Object.Has_Pending_Control,
         Has_Pending_Frame => Object.Has_Pending_Frame,
         Frames_Seen => Object.Frames_Seen,
         Pending_Control => Object.Pending_Control);
   begin
      Session_Arithmetic.Complete_Frame (Transition);
      Object.Pending_Control := Transition.Pending_Control;
      Object.Has_Pending_Control := Transition.Has_Pending_Control;
      Object.Has_Pending_Frame := Transition.Has_Pending_Frame;
      Object.Frames_Seen := Transition.Frames_Seen;
      Object.Current_State := Transition.Current_State;
   end Complete_Frame;
end Giflib.Decoding.Session_Transitions;
