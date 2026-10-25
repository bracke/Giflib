separate (Giflib.Testing.Test_Encoding)
procedure Covers_Options_And_Lifecycle (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Storage : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 512 => 0];
   Destination : aliased Giflib.Streams.Fixed_Buffer_Destination (Storage'Access);
   Encoder : Giflib.Encoding.Encoder (Destination'Access);
   Options : Giflib.Encoding.Encode_Options := Giflib.Encoding.Default_Options;
   Frame : constant Giflib.Encoding.Frame_Info := (others => <>);
   Outcome : Giflib.Results.Result;
begin
   Options.Version := Giflib.Encoding.Force_GIF89a;
   Giflib.Streams.Open (Destination);
   Outcome := Giflib.Encoding.Initialize
     (Encoder, Options);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Encoding.Define_Screen (Encoder, (others => <>));
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Encoding.Set_Global_Palette (Encoder, BW_Palette);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Encoding.Set_Loop_Count (Encoder, 3);
   Assert (Giflib.Results.Succeeded (Outcome), "finite loop definition failed");
   Outcome := Giflib.Encoding.Add_Indexed_Frame
     (Encoder, Frame, Giflib.Encoding.Global_Frame_Palette, [0]);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Encoding.Finish (Encoder);
   Assert (Giflib.Results.Succeeded (Outcome)
           and then Storage (1 .. 6) = [71, 73, 70, 56, 57, 97],
           "forced GIF89a output failed");

   declare
      Encoded : aliased constant Giflib.Streams.Byte_Array :=
        Storage (1 .. Natural (Destination.Offset));
      Source : aliased Giflib.Streams.Memory_Source (Encoded'Access);
      Decoder : Giflib.Decoding.Decoder (Source'Access);
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
   begin
      Giflib.Streams.Open (Source);
      Outcome := Giflib.Decoding.Initialize (Decoder);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Giflib.Results.Succeeded (Outcome)
              and then Header.Version = Giflib.GIF89a
              and then Event.Extension.Loop_Info.Is_Loop
              and then Giflib.Decoding.Looping (Decoder).State
                = Giflib.Animations.Finite_Loop_Count
              and then Giflib.Animations.Raw_Count
                (Giflib.Decoding.Looping (Decoder)) = 3,
              "finite loop or forced GIF89a semantics changed");
   end;

   Giflib.Encoding.Finalize (Encoder);
   Giflib.Streams.Open (Destination);
   Outcome := Giflib.Encoding.Initialize (Encoder);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Encoding.Define_Screen (Encoder, (others => <>));
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Encoding.Cancel (Encoder);
   Assert (Giflib.Results.Succeeded (Outcome)
           and then Giflib.Encoding.State (Encoder) = Giflib.Encoding.Cancelled
           and then Giflib.Encoding.First_Error (Encoder).Code
             = Giflib.Errors.Operation_Cancelled,
           "encoder cancellation state or diagnostic changed");
   Outcome := Giflib.Encoding.Cancel (Encoder);
   Assert (Giflib.Results.Succeeded (Outcome), "repeated encoder cancellation failed");
   Outcome := Giflib.Encoding.Finish (Encoder);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_State
           and then Giflib.Encoding.First_Error (Encoder).Code
             = Giflib.Errors.Operation_Cancelled,
           "cancelled encoder accepted finish or lost its diagnostic");
   Giflib.Encoding.Finalize (Encoder);
   Giflib.Encoding.Finalize (Encoder);
   Assert (Giflib.Encoding.State (Encoder) = Giflib.Encoding.Finalized,
           "encoder finalization was not idempotent");
end Covers_Options_And_Lifecycle;

