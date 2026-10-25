package body Giflib.Encoding.State_Arithmetic
  with SPARK_Mode
is
   procedure Fail (State : out Encoder_State) is
   begin State := Failed; end Fail;
   procedure Initialize (State : in out Encoder_State) is
   begin State := Initialized; end Initialize;
   procedure Define_Screen
     (State : in out Encoder_State;
      Stored_Screen : out Screen_Info;
      Screen : Screen_Info) is
   begin
      Stored_Screen := Screen;
      State := Screen_Defined;
   end Define_Screen;
   procedure Frame_Accepted
     (State : in out Encoder_State;
      Frames_Written : in out Frame_Ordinal) is
   begin
      Frames_Written := Frames_Written + 1;
      State := Accepting_Frames;
   end Frame_Accepted;
   procedure Record_Extension (Extensions_Written : in out Natural) is
   begin
      Extensions_Written := Extensions_Written + 1;
   end Record_Extension;
   procedure Accept_Data (State : in out Encoder_State) is
   begin
      State := Accepting_Frames;
   end Accept_Data;
   procedure Complete (State : in out Encoder_State) is
   begin State := Completed; end Complete;
   procedure Cancel (State : in out Encoder_State) is
   begin State := Cancelled; end Cancel;
   procedure Finalize (State : out Encoder_State) is
   begin State := Finalized; end Finalize;

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
