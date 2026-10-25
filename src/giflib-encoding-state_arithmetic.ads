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

   procedure Fail (State : in out Encoder_State)
     with Post => State = Failed;
   procedure Initialize (State : in out Encoder_State)
     with Pre => Can_Initialize (State),
          Post => State = Initialized;
   procedure Define_Screen
     (Object : in out Encoder;
      Screen : Screen_Info)
     with Pre => Can_Define_Screen (Object.Current_State),
          Post => Object.Current_State = Screen_Defined
                  and then Object.Screen = Screen;
   procedure Frame_Accepted (Object : in out Encoder)
     with Pre => Can_Accept_Data (Object.Current_State)
                 and then Object.Frames_Written < Frame_Ordinal'Last,
          Post => Object.Current_State = Accepting_Frames
                  and then Object.Frames_Written
                    = Object.Frames_Written'Old + 1;
   procedure Record_Extension (Object : in out Encoder)
     with Pre => Object.Extensions_Written < Natural'Last,
          Post => Object.Extensions_Written
                    = Object.Extensions_Written'Old + 1;
   procedure Accept_Data (Object : in out Encoder)
     with Pre => Can_Accept_Data (Object.Current_State),
          Post => Object.Current_State = Accepting_Frames;
   procedure Complete (State : in out Encoder_State)
     with Pre => Can_Finish (State) and then State /= Completed,
          Post => State = Completed;
   procedure Cancel (State : in out Encoder_State)
     with Pre => Can_Cancel (State) and then State /= Cancelled,
          Post => State = Cancelled;
   procedure Finalize (State : in out Encoder_State)
     with Post => State = Finalized;

end Giflib.Encoding.State_Arithmetic;
