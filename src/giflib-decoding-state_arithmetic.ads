private package Giflib.Decoding.State_Arithmetic
  with Preelaborate, SPARK_Mode
is
   procedure Reset (State : in out Decoder_State)
     with Post => State = Uninitialized;
   procedure Fail (State : in out Decoder_State)
     with Post => State = Failed;
   procedure Initialize (State : in out Decoder_State)
     with Pre => State in Uninitialized | Finalized,
          Post => State = Initialized;
   procedure Header_Parsed (State : in out Decoder_State)
     with Pre => State = Initialized,
          Post => State = Header_Ready;
   procedure Frame_Discovered (State : in out Decoder_State)
     with Pre => State = Header_Ready,
          Post => State = Decoding_Frame;
   procedure Await_Frame_Decision (State : in out Decoder_State)
     with Pre => State = Decoding_Frame,
          Post => State = Awaiting_Frame_Decision;
   procedure Begin_Frame (State : in out Decoder_State)
     with Pre => State = Awaiting_Frame_Decision,
          Post => State = Decoding_Frame;
   procedure Complete_Frame (State : in out Decoder_State)
     with Pre => State = Decoding_Frame,
          Post => State = Header_Ready;
   procedure Complete_Stream (State : in out Decoder_State)
     with Pre => State = Header_Ready,
          Post => State = Completed;
   procedure Cancel (State : in out Decoder_State)
     with Pre =>
       State in Initialized | Header_Ready | Awaiting_Frame_Decision
                | Decoding_Frame,
          Post => State = Cancelled;
   procedure Finalize (State : in out Decoder_State)
     with Post => State = Finalized;

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
