separate (Giflib.Testing.Test_Encoding)
procedure Rejects_GIF87a_Features_And_Bad_State (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Storage : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 64 => 0];
   Destination : aliased Giflib.Streams.Fixed_Buffer_Destination (Storage'Access);
   Encoder : Giflib.Encoding.Encoder (Destination'Access);
   Options : Giflib.Encoding.Encode_Options := Giflib.Encoding.Default_Options;
   Outcome : Giflib.Results.Result;
begin
   Outcome := Giflib.Encoding.Define_Screen (Encoder, (others => <>));
   Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_State,
           "screen-before-initialize was accepted");
   Options.Version := Giflib.Encoding.Force_GIF87a;
   Giflib.Streams.Open (Destination);
   Outcome := Giflib.Encoding.Initialize (Encoder, Options);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Encoding.Define_Screen (Encoder, (others => <>));
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Encoding.Set_Loop_Count (Encoder, 0);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Unsupported_Feature,
           "GIF87a loop extension was silently dropped");
   Assert (Destination.Offset = 0, "invalid GIF87a feature wrote partial output");
   Assert
     (Giflib.Encoding.State (Encoder) = Giflib.Encoding.Screen_Defined
      and then Giflib.Encoding.First_Error (Encoder).Code =
        Giflib.Errors.No_Error,
      "rejected preflight request made the encoder terminal");
   Outcome := Giflib.Encoding.Finish (Encoder);
   Giflib.Testing.Assertions.Require_Success (Outcome);

   Giflib.Encoding.Finalize (Encoder);
   Giflib.Streams.Open (Destination);
   Outcome := Giflib.Encoding.Initialize (Encoder);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Encoding.Define_Screen (Encoder, (others => <>));
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Encoding.Add_Decoded_Extension
     (Encoder,
      (Kind => Giflib.Metadata.Graphic_Control_Extension,
       others => <>),
      [1 => 0]);
   Assert
     (Outcome.First_Error.Code = Giflib.Errors.Unsupported_Feature
      and then Destination.Offset = 0
      and then Giflib.Encoding.State (Encoder) =
        Giflib.Encoding.Screen_Defined,
      "decoded graphic control bypassed frame-control encoding");
   Outcome := Giflib.Encoding.Add_Extension
     (Encoder,
      (Kind => Giflib.Encoding.Comment_Extension),
      [1 => 0]);
   Giflib.Testing.Assertions.Require_Success (Outcome);
end Rejects_GIF87a_Features_And_Bad_State;

