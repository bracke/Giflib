package body Giflib.Decoding.State_Arithmetic
  with SPARK_Mode
is
   procedure Reset (State : in out Decoder_State) is
   begin State := Uninitialized; end Reset;
   procedure Fail (State : in out Decoder_State) is
   begin State := Failed; end Fail;
   procedure Initialize (State : in out Decoder_State) is
   begin State := Initialized; end Initialize;
   procedure Header_Parsed
     (Object : in out Decoder;
      Header : Header_Info) is
   begin
      Object.Header_Data := Header;
      Object.Current_State := Header_Ready;
   end Header_Parsed;
   procedure Frame_Discovered (Object : in out Decoder) is
   begin Object.Current_State := Decoding_Frame; end Frame_Discovered;
   procedure Await_Frame_Decision (Object : in out Decoder) is
   begin
      Object.Has_Pending_Frame := True;
      Object.Current_State := Awaiting_Frame_Decision;
   end Await_Frame_Decision;
   procedure Begin_Frame (Object : in out Decoder) is
   begin Object.Current_State := Decoding_Frame; end Begin_Frame;
   procedure Complete_Frame (Object : in out Decoder) is
   begin
      Object.Pending_Control := Frames.Default_Control;
      Object.Has_Pending_Control := False;
      Object.Has_Pending_Frame := False;
      Object.Frames_Seen := Object.Frames_Seen + 1;
      Object.Current_State := Header_Ready;
   end Complete_Frame;
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
