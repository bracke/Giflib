package body Giflib.Encoding.Session_Transitions is
   procedure Begin_Session
     (Object : in out Encoder;
      Options : Encode_Options;
      Constraints : Limits.Limit_Set) is
   begin
      Object.Options := Options;
      Object.Constraints := Constraints;
      Object.Screen := (others => <>);
      Object.Global_Palette := (others => <>);
      Object.Has_Global_Palette := False;
      Object.Loop_Data := Animations.No_Loop;
      Object.Header_Written := False;
      Object.Frames_Written := 0;
      Object.Extensions_Written := 0;
      Object.Bytes_Written := 0;
      Object.Compressed_Bytes_Written := 0;
      Object.Diagnostic := Errors.Make (Errors.No_Error);
      State_Arithmetic.Initialize (Object.Current_State);
   end Begin_Session;

   procedure Fail_Session (Object : in out Encoder) is
   begin
      State_Arithmetic.Fail (Object.Current_State);
   end Fail_Session;

   procedure Define_Screen
     (Object : in out Encoder;
      Screen : Screen_Info) is
   begin
      State_Arithmetic.Define_Screen
        (Object.Current_State, Object.Screen, Screen);
   end Define_Screen;

   procedure Set_Global_Palette
     (Object : in out Encoder;
      Palette : Palettes.Palette) is
   begin
      Object.Global_Palette := Palette;
      Object.Has_Global_Palette := True;
   end Set_Global_Palette;

   procedure Set_Loop
     (Object : in out Encoder;
      Looping : Animations.Loop_Info) is
   begin
      Object.Loop_Data := Looping;
   end Set_Loop;

   procedure Commit_Header
     (Object : in out Encoder;
      Loop_Extension_Written : Boolean) is
   begin
      if Loop_Extension_Written then
         State_Arithmetic.Record_Extension (Object.Extensions_Written);
      end if;
      Object.Header_Written := True;
   end Commit_Header;

   procedure Record_Extension (Object : in out Encoder) is
   begin
      State_Arithmetic.Record_Extension (Object.Extensions_Written);
   end Record_Extension;

   procedure Complete_Extension (Object : in out Encoder) is
   begin
      State_Arithmetic.Record_Extension (Object.Extensions_Written);
      State_Arithmetic.Accept_Data (Object.Current_State);
   end Complete_Extension;

   procedure Complete_Session (Object : in out Encoder) is
   begin
      State_Arithmetic.Complete (Object.Current_State);
   end Complete_Session;

   procedure Cancel_Session (Object : in out Encoder) is
   begin
      State_Arithmetic.Cancel (Object.Current_State);
      Object.Diagnostic := Errors.Make (Errors.Operation_Cancelled);
   end Cancel_Session;

   procedure Record_Output
     (Object : in out Encoder;
      Compressed : Byte_Count;
      Wire_Bytes : Byte_Count) is
   begin
      Object.Bytes_Written := Object.Bytes_Written + Wire_Bytes;
      Object.Compressed_Bytes_Written :=
        Object.Compressed_Bytes_Written + Compressed;
   end Record_Output;

   procedure Record_Wire_Bytes
     (Object : in out Encoder;
      Count : Byte_Count) is
   begin
      Object.Bytes_Written := Object.Bytes_Written + Count;
   end Record_Wire_Bytes;

   procedure Complete_Frame
     (Object : in out Encoder;
      Compressed : Byte_Count;
      Wire_Bytes : Byte_Count) is
   begin
      Record_Output (Object, Compressed, Wire_Bytes);
      State_Arithmetic.Frame_Accepted
        (Object.Current_State, Object.Frames_Written);
   end Complete_Frame;

   procedure Finalize_Session (Object : in out Encoder) is
   begin
      State_Arithmetic.Finalize (Object.Current_State);
   end Finalize_Session;
end Giflib.Encoding.Session_Transitions;
