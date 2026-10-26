separate (Giflib.Testing.Test_Streams)
procedure Diagnostic_Positions_Are_Sampled_Once
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Outcome : Giflib.Results.Result;
   Source_Calls : aliased Natural := 0;
   Destination_Calls : aliased Natural := 0;
   Retry_Calls : aliased Natural := 0;
   Truncated_Calls : aliased Natural := 0;
   Sequenced_Calls : aliased Natural := 0;
   Counted_Source : Counting_Source (Source_Calls'Access);
   Counted_Destination : Counting_Destination
     (Destination_Calls'Access, 0, False);
   Retry_Destination : aliased Counting_Destination
     (Retry_Calls'Access, 1, False);
   Retry_Encoder : Giflib.Encoding.Encoder (Retry_Destination'Access);
   Truncated_Source : aliased Counting_Source (Truncated_Calls'Access);
   Truncated_Decoder : Giflib.Decoding.Decoder (Truncated_Source'Access);
   Sequenced_Destination : aliased Counting_Destination
     (Sequenced_Calls'Access, 1, True);
   Sequenced_Encoder : Giflib.Encoding.Encoder
     (Sequenced_Destination'Access);
   Context : Giflib.Errors.Diagnostic_Context;
begin
   Context := Giflib.Internal.Diagnostics.At_Source (Counted_Source);
   Context := Giflib.Internal.Diagnostics.At_Source
     (Counted_Source, Context);
   Assert
     (Source_Calls = 1
      and then Context.Source_Position.State =
        Giflib.Errors.Position_Available
      and then Context.Source_Position.Value = 17,
      "source diagnostic sampled Offset more than once");
   Context := Giflib.Internal.Diagnostics.At_Destination
     (Counted_Destination);
   Context := Giflib.Internal.Diagnostics.At_Destination
     (Counted_Destination, Context);
   Assert
     (Destination_Calls = 1
      and then Context.Destination_Position.State =
        Giflib.Errors.Position_Available
      and then Context.Destination_Position.Value = 23,
      "destination diagnostic sampled Offset more than once");
   Outcome := Giflib.Encoding.Initialize (Retry_Encoder);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Encoding.Initialize (Retry_Encoder);
   Assert
     (not Giflib.Results.Succeeded (Outcome)
      and then Retry_Calls = 1
      and then Outcome.First_Error.Context.Destination_Position.State =
        Giflib.Errors.Position_Unavailable,
      "encoder retried an unavailable diagnostic position");
   Outcome := Giflib.Decoding.Initialize (Truncated_Decoder);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   declare
      Header : Giflib.Decoding.Header_Info;
   begin
      Outcome := Giflib.Decoding.Read_Header (Truncated_Decoder, Header);
   end;
   Assert
     (not Giflib.Results.Succeeded (Outcome)
      and then Truncated_Calls = 2
      and then Outcome.First_Error.Context.Source_Position.State =
        Giflib.Errors.Position_Available,
      "truncated-block decoration resampled the source position");

   Outcome := Giflib.Encoding.Initialize (Sequenced_Encoder);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Encoding.Define_Screen
     (Sequenced_Encoder, (others => <>));
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Encoding.Finish (Sequenced_Encoder);
   Assert
     (not Giflib.Results.Succeeded (Outcome)
      and then Sequenced_Calls = 1
      and then Outcome.First_Error.Context.Destination_Position.State =
        Giflib.Errors.Position_Unavailable,
      "zero-progress decoration resampled the destination position");
end Diagnostic_Positions_Are_Sampled_Once;
