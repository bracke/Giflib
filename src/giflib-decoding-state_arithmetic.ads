private package Giflib.Decoding.State_Arithmetic
  with Preelaborate, SPARK_Mode
is
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

   procedure Reset (State : out Decoder_State)
     with Post => State = Uninitialized;
   procedure Fail (State : out Decoder_State)
     with Post => State = Failed;
   procedure Initialize (State : in out Decoder_State)
     with Pre => Can_Initialize (State),
          Post => State = Initialized;
   procedure Header_Parsed
     (State : in out Decoder_State)
     with Pre => State = Initialized,
          Post => State = Header_Ready;
   procedure Frame_Discovered (State : in out Decoder_State)
     with Pre => State = Header_Ready,
          Post => State = Decoding_Frame;
   procedure Await_Frame_Decision
     (State : in out Decoder_State;
      Has_Pending_Frame : out Boolean)
     with Pre => State = Decoding_Frame,
          Post => State = Awaiting_Frame_Decision and then Has_Pending_Frame;
   procedure Begin_Frame (State : in out Decoder_State)
     with Pre => Can_Process_Frame (State),
          Post => State = Decoding_Frame;
   procedure Complete_Frame
     (State : in out Decoder_State;
      Has_Pending_Control : out Boolean;
      Has_Pending_Frame : in out Boolean;
      Frames_Seen : in out Frame_Ordinal)
     with Pre => State = Decoding_Frame
                 and then Has_Pending_Frame
                 and then Frames_Seen < Frame_Ordinal'Last,
          Post => State = Header_Ready
                  and then not Has_Pending_Frame
                  and then not Has_Pending_Control
                  and then Frames_Seen = Frames_Seen'Old + 1;
   procedure Complete_Stream (State : in out Decoder_State)
     with Pre => State = Header_Ready,
          Post => State = Completed;
   procedure Cancel (State : in out Decoder_State)
     with Pre => Can_Cancel (State),
          Post => State = Cancelled;
   procedure Finalize (State : out Decoder_State)
     with Post => State = Finalized;

end Giflib.Decoding.State_Arithmetic;
