private package Giflib.Encoding.State_Arithmetic
  with Preelaborate, SPARK_Mode
is
   function Can_Initialize (State : Encoder_State) return Boolean
     with Post =>
       Can_Initialize'Result = (State in Uninitialized | Finalized);

   function Can_Define_Screen (State : Encoder_State) return Boolean
     with Post => Can_Define_Screen'Result = (State = Initialized);

   function Can_Configure
     (State : Encoder_State;
      Header_Written : Boolean) return Boolean
     with Post =>
       Can_Configure'Result =
         (State = Screen_Defined and then not Header_Written);

   function Can_Accept_Data (State : Encoder_State) return Boolean
     with Post =>
       Can_Accept_Data'Result =
         (State in Screen_Defined | Accepting_Frames);

   function Can_Finish (State : Encoder_State) return Boolean
     with Post =>
       Can_Finish'Result =
         (State in Screen_Defined | Accepting_Frames | Completed);

   function Can_Cancel (State : Encoder_State) return Boolean
     with Post =>
       Can_Cancel'Result =
         (State in Initialized | Screen_Defined | Accepting_Frames | Cancelled);
end Giflib.Encoding.State_Arithmetic;
