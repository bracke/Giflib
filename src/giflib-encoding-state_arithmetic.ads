private package Giflib.Encoding.State_Arithmetic
  with Preelaborate, SPARK_Mode
is
   function Can_Initialize (State : Encoder_State) return Boolean
     with Post =>
       Can_Initialize'Result = (State in Uninitialized | Finalized);
   function Can_Define_Screen (State : Encoder_State) return Boolean
     with Post => Can_Define_Screen'Result = (State = Initialized);
   function Can_Configure
     (State : Encoder_State;
      Header_Written : Boolean) return Boolean
     with Post =>
       Can_Configure'Result =
         (State = Screen_Defined and then not Header_Written);
   function Can_Accept_Data (State : Encoder_State) return Boolean
     with Post =>
       Can_Accept_Data'Result =
         (State in Screen_Defined | Accepting_Frames);
   function Can_Finish (State : Encoder_State) return Boolean
     with Post =>
       Can_Finish'Result =
         (State in Screen_Defined | Accepting_Frames | Completed);
   function Can_Cancel (State : Encoder_State) return Boolean
     with Post =>
       Can_Cancel'Result =
         (State in Initialized | Screen_Defined | Accepting_Frames | Cancelled);

   procedure Fail (State : out Encoder_State)
     with Post => State = Failed;
   procedure Initialize (State : in out Encoder_State)
     with Pre => Can_Initialize (State),
          Post => State = Initialized;
   procedure Define_Screen
     (State : in out Encoder_State;
      Stored_Screen : out Screen_Info;
      Screen : Screen_Info)
     with Pre => Can_Define_Screen (State),
          Post => State = Screen_Defined and then Stored_Screen = Screen;
   procedure Frame_Accepted
     (State : in out Encoder_State;
      Frames_Written : in out Frame_Ordinal)
     with Pre => Can_Accept_Data (State)
                 and then Frames_Written < Frame_Ordinal'Last,
          Post => State = Accepting_Frames
                  and then Frames_Written = Frames_Written'Old + 1;
   procedure Record_Extension (Extensions_Written : in out Natural)
     with Pre => Extensions_Written < Natural'Last,
          Post => Extensions_Written = Extensions_Written'Old + 1;
   procedure Accept_Data (State : in out Encoder_State)
     with Pre => Can_Accept_Data (State),
          Post => State = Accepting_Frames;
   procedure Complete (State : in out Encoder_State)
     with Pre => Can_Finish (State) and then State /= Completed,
          Post => State = Completed;
   procedure Cancel (State : in out Encoder_State)
     with Pre => Can_Cancel (State) and then State /= Cancelled,
          Post => State = Cancelled;
   procedure Finalize (State : out Encoder_State)
     with Post => State = Finalized;

end Giflib.Encoding.State_Arithmetic;
