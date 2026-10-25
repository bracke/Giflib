with Giflib.Decoding.Session_Arithmetic;

package body Giflib.Decoding.Session_Transitions is
   procedure Reset_Session_Data (Object : in out Decoder) is
   begin
      Object.Header_Data := (others => <>);
      Object.Frames_Seen := 0;
      Object.Total_Decoded_Pixels := 0;
      Object.Total_Compressed_Bytes := 0;
      Object.Extensions_Seen := 0;
      Object.Pending_Control := Frames.Default_Control;
      Object.Has_Pending_Control := False;
      Object.Pending_Frame := (others => <>);
      Object.Has_Pending_Frame := False;
      Object.Loop_Data := Animations.No_Loop;
      Object.Snapshot_Rectangle := (others => <>);
      Object.Previous_Rectangle := (others => <>);
      Object.Previous_Control := Frames.Default_Control;
      Object.Has_Previous_Frame := False;
      Object.Stored_Warnings := 0;
   end Reset_Session_Data;

   procedure Begin_Session
     (Object : in out Decoder;
      Options : Decode_Options;
      Constraints : Limits.Limit_Set) is
   begin
      Object.Options := Options;
      Object.Constraints := Constraints;
      Reset_Session_Data (Object);
      Object.Diagnostic := Errors.Make (Errors.No_Error);
      State_Arithmetic.Initialize (Object.Current_State);
   end Begin_Session;

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

   procedure Finalize_Session (Object : in out Decoder) is
   begin
      Reset_Session_Data (Object);
      State_Arithmetic.Finalize (Object.Current_State);
   end Finalize_Session;
end Giflib.Decoding.Session_Transitions;
