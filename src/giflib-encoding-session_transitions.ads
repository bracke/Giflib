with Giflib.Encoding.State_Arithmetic;

private package Giflib.Encoding.Session_Transitions
  with Preelaborate
is
   use type Limits.Limit_Set;
   use type Animations.Loop_Info;
   use type Errors.Error_Code;
   use type Palettes.Palette;

   function Session_Data_Is_Initialized (Object : Encoder) return Boolean is
     (Object.Screen = Screen_Info'(others => <>)
      and then Object.Global_Palette = Palettes.Palette'(others => <>)
      and then not Object.Has_Global_Palette
      and then Object.Loop_Data = Animations.No_Loop
      and then not Object.Header_Written
      and then Object.Frames_Written = 0
      and then Object.Extensions_Written = 0
      and then Object.Bytes_Written = 0
      and then Object.Compressed_Bytes_Written = 0
      and then Object.Diagnostic.Code = Errors.No_Error);

   procedure Begin_Session
     (Object : in out Encoder;
      Options : Encode_Options;
      Constraints : Limits.Limit_Set)
     with Pre => State_Arithmetic.Can_Initialize (Object.Current_State),
          Post => Object.Current_State = Initialized
                  and then Object.Options = Options
                  and then Object.Constraints = Constraints
                  and then Session_Data_Is_Initialized (Object);

   procedure Fail_Session (Object : in out Encoder)
     with Post => Object.Current_State = Failed;

   procedure Define_Screen
     (Object : in out Encoder;
      Screen : Screen_Info)
     with Pre => Object.Current_State = Initialized,
          Post => Object.Current_State = Screen_Defined
                  and then Object.Screen = Screen;

   procedure Set_Global_Palette
     (Object : in out Encoder;
      Palette : Palettes.Palette)
     with Post => Object.Global_Palette = Palette
                  and then Object.Has_Global_Palette;

   procedure Set_Loop
     (Object : in out Encoder;
      Looping : Animations.Loop_Info)
     with Post => Object.Loop_Data = Looping;

   procedure Commit_Header
     (Object : in out Encoder;
      Loop_Extension_Written : Boolean)
     with Pre => not Object.Header_Written
                 and then (not Loop_Extension_Written
                           or else Object.Extensions_Written
                             < Natural'Last),
          Post => Object.Header_Written
                  and then Object.Extensions_Written =
                    Object.Extensions_Written'Old
                      + Boolean'Pos (Loop_Extension_Written);

   procedure Record_Extension (Object : in out Encoder)
     with Pre => Object.Extensions_Written < Natural'Last,
          Post => Object.Extensions_Written =
                    Object.Extensions_Written'Old + 1;

   procedure Complete_Extension (Object : in out Encoder)
     with Pre => Object.Extensions_Written < Natural'Last,
          Post => Object.Current_State = Accepting_Frames
                  and then Object.Extensions_Written =
                    Object.Extensions_Written'Old + 1;

   procedure Complete_Session (Object : in out Encoder)
     with Post => Object.Current_State = Completed;

   procedure Cancel_Session (Object : in out Encoder)
     with Pre => State_Arithmetic.Can_Cancel (Object.Current_State),
          Post => Object.Current_State = Cancelled
                  and then Object.Diagnostic.Code = Errors.Operation_Cancelled;

   procedure Record_Output
     (Object : in out Encoder;
      Compressed : Byte_Count;
      Wire_Bytes : Byte_Count)
     with Pre => Object.Bytes_Written <= Byte_Count'Last - Wire_Bytes
                 and then Object.Compressed_Bytes_Written
                   <= Byte_Count'Last - Compressed,
          Post => Object.Bytes_Written = Object.Bytes_Written'Old + Wire_Bytes
                  and then Object.Compressed_Bytes_Written =
                    Object.Compressed_Bytes_Written'Old + Compressed;

   procedure Record_Wire_Bytes
     (Object : in out Encoder;
      Count : Byte_Count)
     with Pre => Object.Bytes_Written <= Byte_Count'Last - Count,
          Post => Object.Bytes_Written = Object.Bytes_Written'Old + Count;

   procedure Complete_Frame
     (Object : in out Encoder;
      Compressed : Byte_Count;
      Wire_Bytes : Byte_Count)
     with Pre => State_Arithmetic.Can_Accept_Data (Object.Current_State)
                 and then Object.Frames_Written < Frame_Ordinal'Last
                 and then Object.Bytes_Written <= Byte_Count'Last - Wire_Bytes
                 and then Object.Compressed_Bytes_Written
                   <= Byte_Count'Last - Compressed,
          Post => Object.Current_State = Accepting_Frames
                  and then Object.Frames_Written =
                    Object.Frames_Written'Old + 1
                  and then Object.Bytes_Written =
                    Object.Bytes_Written'Old + Wire_Bytes
                  and then Object.Compressed_Bytes_Written =
                    Object.Compressed_Bytes_Written'Old + Compressed;

   procedure Finalize_Session (Object : in out Encoder)
     with Post => Object.Current_State = Finalized;
end Giflib.Encoding.Session_Transitions;
