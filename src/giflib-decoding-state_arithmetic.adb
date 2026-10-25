package body Giflib.Decoding.State_Arithmetic
  with SPARK_Mode
is
   function Can_Transition
     (State : Decoder_State;
      Target : Decoder_State) return Boolean
   is
     (Target in Uninitialized | Failed | Finalized
      or else (Target = Initialized
               and then State in Uninitialized | Finalized)
      or else (Target = Header_Ready
               and then State in Initialized | Decoding_Frame)
      or else (Target = Decoding_Frame
               and then State in Header_Ready | Awaiting_Frame_Decision)
      or else (Target = Awaiting_Frame_Decision
               and then State = Decoding_Frame)
      or else (Target = Completed and then State = Header_Ready)
      or else (Target = Cancelled and then Can_Cancel (State)));

   procedure Transition
     (State : in out Decoder_State;
      Target : Decoder_State)
   is
   begin
      State := Target;
   end Transition;

   function Can_Initialize (State : Decoder_State) return Boolean is
     (State in Uninitialized | Finalized);

   function Can_Read_Header (State : Decoder_State) return Boolean is
     (State = Initialized);

   function Can_Read_Event (State : Decoder_State) return Boolean is
     (State in Header_Ready | Completed);

   function Can_Process_Frame (State : Decoder_State) return Boolean is
     (State = Awaiting_Frame_Decision);

   function Can_Cancel (State : Decoder_State) return Boolean is
     (State in Initialized | Header_Ready | Awaiting_Frame_Decision
             | Decoding_Frame);
end Giflib.Decoding.State_Arithmetic;
