package body Giflib.Encoding.State_Arithmetic
  with SPARK_Mode
is
   procedure Fail (State : in out Encoder_State) is
   begin State := Failed; end Fail;
   procedure Initialize (State : in out Encoder_State) is
   begin State := Initialized; end Initialize;
   procedure Define_Screen
     (Object : in out Encoder;
      Screen : Screen_Info) is
   begin
      Object.Screen := Screen;
      Object.Current_State := Screen_Defined;
   end Define_Screen;
   procedure Frame_Accepted (Object : in out Encoder) is
   begin
      Object.Frames_Written := Object.Frames_Written + 1;
      Object.Current_State := Accepting_Frames;
   end Frame_Accepted;
   procedure Record_Extension (Object : in out Encoder) is
   begin
      Object.Extensions_Written := Object.Extensions_Written + 1;
   end Record_Extension;
   procedure Accept_Data (Object : in out Encoder) is
   begin
      Object.Current_State := Accepting_Frames;
   end Accept_Data;
   procedure Complete (State : in out Encoder_State) is
   begin State := Completed; end Complete;
   procedure Cancel (State : in out Encoder_State) is
   begin State := Cancelled; end Cancel;
   procedure Finalize (State : in out Encoder_State) is
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
