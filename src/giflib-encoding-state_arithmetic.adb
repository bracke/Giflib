package body Giflib.Encoding.State_Arithmetic
  with SPARK_Mode
is
   function Can_Transition
     (State : Encoder_State;
      Target : Encoder_State) return Boolean
   is
     (Target in Failed | Finalized
      or else (Target = Initialized
               and then State in Uninitialized | Finalized)
      or else (Target = Screen_Defined and then State = Initialized)
      or else (Target = Accepting_Frames
               and then State in Screen_Defined | Accepting_Frames)
      or else (Target = Completed
               and then State in Screen_Defined | Accepting_Frames)
      or else (Target = Cancelled and then Can_Cancel (State)));

   procedure Transition
     (State : in out Encoder_State;
      Target : Encoder_State)
   is
   begin
      State := Target;
   end Transition;

   function Can_Initialize (State : Encoder_State) return Boolean is
     (State in Uninitialized | Finalized);

   function Can_Define_Screen (State : Encoder_State) return Boolean is
     (State = Initialized);

   function Can_Configure
     (State : Encoder_State;
      Header_Written : Boolean) return Boolean
   is (State = Screen_Defined and then not Header_Written);

   function Can_Accept_Data (State : Encoder_State) return Boolean is
     (State in Screen_Defined | Accepting_Frames);

   function Can_Finish (State : Encoder_State) return Boolean is
     (State in Screen_Defined | Accepting_Frames | Completed);

   function Can_Cancel (State : Encoder_State) return Boolean is
     (State in Initialized | Screen_Defined | Accepting_Frames | Cancelled);
end Giflib.Encoding.State_Arithmetic;
