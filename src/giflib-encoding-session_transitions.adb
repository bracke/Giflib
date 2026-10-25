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

   procedure Record_Output
     (Object : in out Encoder;
      Compressed : Byte_Count;
      Wire_Bytes : Byte_Count) is
   begin
      Object.Bytes_Written := Object.Bytes_Written + Wire_Bytes;
      Object.Compressed_Bytes_Written :=
        Object.Compressed_Bytes_Written + Compressed;
   end Record_Output;

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
