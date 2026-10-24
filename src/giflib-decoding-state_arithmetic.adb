package body Giflib.Decoding.State_Arithmetic
  with SPARK_Mode
is
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
