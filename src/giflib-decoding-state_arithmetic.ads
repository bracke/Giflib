private package Giflib.Decoding.State_Arithmetic
  with Preelaborate, SPARK_Mode
is
   function Can_Transition
     (State : Decoder_State;
      Target : Decoder_State) return Boolean;

   procedure Transition
     (State : in out Decoder_State;
      Target : Decoder_State)
     with Pre => Can_Transition (State, Target),
          Post => State = Target;

   function Can_Initialize (State : Decoder_State) return Boolean
     with Post =>
       Can_Initialize'Result = (State in Uninitialized | Finalized);

   function Can_Read_Header (State : Decoder_State) return Boolean
     with Post => Can_Read_Header'Result = (State = Initialized);

   function Can_Read_Event (State : Decoder_State) return Boolean
     with Post =>
       Can_Read_Event'Result = (State in Header_Ready | Completed);

   function Can_Process_Frame (State : Decoder_State) return Boolean
     with Post =>
       Can_Process_Frame'Result = (State = Awaiting_Frame_Decision);

   function Can_Cancel (State : Decoder_State) return Boolean
     with Post =>
       Can_Cancel'Result =
         (State in Initialized | Header_Ready | Awaiting_Frame_Decision
                 | Decoding_Frame);
end Giflib.Decoding.State_Arithmetic;
