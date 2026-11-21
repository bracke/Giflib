package body Giflib.Decoding.Session_Transitions is
   procedure Reset_Session_Data (Object : in out Decoder) is
   begin
      Object.Header_Data := (others => <>);
      Object.Frames_Seen := 0;
      Object.Total_Decoded_Pixels := 0;
      Object.Total_Compressed_Bytes := 0;
      Object.Extensions_Seen := 0;
      Object.Pending_Control := (Present => False);
      Object.Pending_Frame := (Present => False);
      Object.Loop_Data := Animations.No_Loop;
      Object.Previous_Frame := (Present => False);
      Object.Stored_Warnings := 0;
   end Reset_Session_Data;

   procedure Begin_Session
     (Object : in out Decoder;
      Options : Decode_Options;
      Constraints : Limits.Limit_Set) is
   begin
      Object.Options := Options;
      Object.Constraints := Constraints;
      Reset_Session_Data (Object);
      Object.Diagnostic := Errors.No_Error_Value;
      State_Arithmetic.Initialize (Object.Current_State);
   end Begin_Session;

   procedure Commit_Header
     (Object : in out Decoder;
      Header : Header_Info) is
   begin
      Object.Header_Data := Header;
      State_Arithmetic.Header_Read (Object.Current_State);
   end Commit_Header;

   procedure Fail_Session
     (Object : in out Decoder;
      Diagnostic : Errors.Error) is
   begin
      if Object.Diagnostic.Code = Errors.No_Error then
         Object.Diagnostic := Diagnostic;
      end if;
      State_Arithmetic.Fail (Object.Current_State);
   end Fail_Session;

   procedure Record_Diagnostic
     (Object : in out Decoder;
      Diagnostic : Errors.Error) is
   begin
      if Object.Diagnostic.Code = Errors.No_Error then
         Object.Diagnostic := Diagnostic;
      end if;
   end Record_Diagnostic;

   procedure Record_Warning
     (Object : in out Decoder;
      Item : Errors.Warning)
   is
      Capacity : constant Limits.Warning_Record_Limit :=
        Object.Constraints.Max_Warning_Records;
   begin
      if Capacity = 0 then
         return;
      elsif Object.Stored_Warnings < Capacity then
         Object.Stored_Warnings := Object.Stored_Warnings + 1;
         Object.Warnings (Object.Stored_Warnings) := Item;
      elsif Object.Warnings (Capacity).Code /= Errors.Warnings_Suppressed then
         Object.Warnings (Capacity) :=
           Errors.Make_Warning
             (Errors.Warnings_Suppressed, Errors.Data_Loss, Item.Context);
      end if;
   end Record_Warning;

   procedure Reset_Session (Object : in out Decoder) is
   begin
      State_Arithmetic.Reset (Object.Current_State);
      Object.Diagnostic := Errors.No_Error_Value;
   end Reset_Session;

   procedure Discover_Frame (Object : in out Decoder) is
   begin
      State_Arithmetic.Frame_Discovered (Object.Current_State);
   end Discover_Frame;

   procedure Await_Frame_Decision (Object : in out Decoder) is
   begin
      State_Arithmetic.Await_Frame_Decision (Object.Current_State);
   end Await_Frame_Decision;

   procedure Stage_Frame
     (Object : in out Decoder;
      Frame : Prepared_Frame) is
   begin
      Object.Pending_Frame := Frame;
   end Stage_Frame;

   procedure Begin_Frame (Object : in out Decoder) is
   begin
      State_Arithmetic.Begin_Frame (Object.Current_State);
   end Begin_Frame;

   procedure Record_Extension (Object : in out Decoder) is
   begin
      Object.Extensions_Seen := Object.Extensions_Seen + 1;
   end Record_Extension;

   procedure Set_Pending_Control
     (Object : in out Decoder;
      Control : Frames.Graphic_Control) is
   begin
      Object.Pending_Control := (Present => True, Value => Control);
   end Set_Pending_Control;

   procedure Clear_Pending_Control (Object : in out Decoder) is
   begin
      Object.Pending_Control := (Present => False);
   end Clear_Pending_Control;

   procedure Set_Loop
     (Object : in out Decoder;
      Looping : Animations.Loop_Info) is
   begin
      Object.Loop_Data := Looping;
   end Set_Loop;

   procedure Commit_Resource_Usage
     (Object : in out Decoder;
      Decoded_Pixels : Pixel_Count;
      Compressed_Bytes : Byte_Count) is
   begin
      Object.Total_Decoded_Pixels := Decoded_Pixels;
      Object.Total_Compressed_Bytes := Compressed_Bytes;
   end Commit_Resource_Usage;

   procedure Clear_Resource_State (Object : in out Decoder) is
   begin
      Object.Pending_Frame := (Present => False);
      Object.Previous_Frame := (Present => False);
   end Clear_Resource_State;

   procedure Clear_Previous_Frame (Object : in out Decoder) is
   begin
      Object.Previous_Frame := (Present => False);
   end Clear_Previous_Frame;

   procedure Commit_Composited_Frame
     (Object : in out Decoder;
      Rectangle : Frames.Rectangle;
      Control : Frames.Graphic_Control) is
   begin
      Object.Previous_Frame :=
        (Present => True,
         Rectangle => Rectangle,
         Control => Control,
         Snapshot_Rectangle => Rectangle);
   end Commit_Composited_Frame;

   procedure Complete_Stream (Object : in out Decoder) is
   begin
      State_Arithmetic.Complete_Stream (Object.Current_State);
   end Complete_Stream;

   procedure Cancel_Session (Object : in out Decoder) is
   begin
      State_Arithmetic.Cancel (Object.Current_State);
      Object.Diagnostic := Errors.Make (Errors.Operation_Cancelled);
   end Cancel_Session;

   procedure Complete_Frame (Object : in out Decoder) is
   begin
      Object.Pending_Control := (Present => False);
      Object.Pending_Frame := (Present => False);
      State_Arithmetic.Complete_Frame
        (Object.Current_State, Object.Frames_Seen);
   end Complete_Frame;

   procedure Finalize_Session (Object : in out Decoder) is
   begin
      Reset_Session_Data (Object);
      State_Arithmetic.Finalize (Object.Current_State);
   end Finalize_Session;
end Giflib.Decoding.Session_Transitions;
