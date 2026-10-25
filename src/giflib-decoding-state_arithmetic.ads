private package Giflib.Decoding.State_Arithmetic
  with Preelaborate, SPARK_Mode
is
   use type Header_Info;
   use type Frames.Graphic_Control;
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

   procedure Reset (State : in out Decoder_State)
     with Post => State = Uninitialized;
   procedure Fail (State : in out Decoder_State)
     with Post => State = Failed;
   procedure Initialize (State : in out Decoder_State)
     with Pre => Can_Initialize (State),
          Post => State = Initialized;
   procedure Header_Parsed
     (Object : in out Decoder;
      Header : Header_Info)
     with Pre => Object.Current_State = Initialized,
          Post => Object.Current_State = Header_Ready
                  and then Object.Header_Data = Header;
   procedure Frame_Discovered (Object : in out Decoder)
     with Pre => Object.Current_State = Header_Ready,
          Post => Object.Current_State = Decoding_Frame;
   procedure Await_Frame_Decision (Object : in out Decoder)
     with Pre => Object.Current_State = Decoding_Frame,
          Post => Object.Current_State = Awaiting_Frame_Decision
                  and then Object.Has_Pending_Frame;
   procedure Begin_Frame (Object : in out Decoder)
     with Pre => Can_Process_Frame (Object.Current_State),
          Post => Object.Current_State = Decoding_Frame;
   procedure Complete_Frame (Object : in out Decoder)
     with Pre => Object.Current_State = Decoding_Frame
                 and then Object.Has_Pending_Frame
                 and then Object.Frames_Seen < Frame_Ordinal'Last,
          Post => Object.Current_State = Header_Ready
                  and then not Object.Has_Pending_Frame
                  and then not Object.Has_Pending_Control
                  and then Object.Pending_Control = Frames.Default_Control
                  and then Object.Frames_Seen
                    = Object.Frames_Seen'Old + 1;
   procedure Complete_Stream (State : in out Decoder_State)
     with Pre => State = Header_Ready,
          Post => State = Completed;
   procedure Cancel (State : in out Decoder_State)
     with Pre => Can_Cancel (State),
          Post => State = Cancelled;
   procedure Finalize (State : in out Decoder_State)
     with Post => State = Finalized;

end Giflib.Decoding.State_Arithmetic;
