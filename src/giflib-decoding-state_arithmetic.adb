package body Giflib.Decoding.State_Arithmetic
  with SPARK_Mode
is
   procedure Reset (State : in out Decoder_State) is
   begin State := Uninitialized; end Reset;
   procedure Fail (State : in out Decoder_State) is
   begin State := Failed; end Fail;
   procedure Initialize (State : in out Decoder_State) is
   begin State := Initialized; end Initialize;
   procedure Header_Parsed (State : in out Decoder_State) is
   begin State := Header_Ready; end Header_Parsed;
   procedure Frame_Discovered (State : in out Decoder_State) is
   begin State := Decoding_Frame; end Frame_Discovered;
   procedure Await_Frame_Decision (State : in out Decoder_State) is
   begin State := Awaiting_Frame_Decision; end Await_Frame_Decision;
   procedure Begin_Frame (State : in out Decoder_State) is
   begin State := Decoding_Frame; end Begin_Frame;
   procedure Complete_Frame (State : in out Decoder_State) is
   begin State := Header_Ready; end Complete_Frame;
   procedure Complete_Stream (State : in out Decoder_State) is
   begin State := Completed; end Complete_Stream;
   procedure Cancel (State : in out Decoder_State) is
   begin State := Cancelled; end Cancel;
   procedure Finalize (State : in out Decoder_State) is
   begin State := Finalized; end Finalize;

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
