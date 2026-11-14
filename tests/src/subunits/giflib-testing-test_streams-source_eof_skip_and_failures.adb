separate (Giflib.Testing.Test_Streams)
procedure Source_EOF_Skip_And_Failures (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Input : aliased constant Giflib.Streams.Byte_Array := [1, 2, 3];
   Target : Giflib.Streams.Byte_Array (1 .. 4) := [others => 0];
   Source : Giflib.Streams.Memory_Source (Input'Access);
   Failed_Source : Raising_Source;
   Outcome : Giflib.Results.Result;
begin
   Giflib.Streams.Open (Source, Max_Transfer => 1);
   Outcome := Giflib.Streams.Skip_Exact (Source, 2);
   Assert (Giflib.Results.Succeeded (Outcome) and then Source.Offset = 2, "partial skips were not completed");
   Outcome := Giflib.Streams.Skip_Exact (Source, 2);
   Assert (not Giflib.Results.Succeeded (Outcome), "skip beyond EOF succeeded");
   Assert (Outcome.First_Error.Code = Giflib.Errors.Source_Unexpected_End, "skip EOF has wrong error");

   Giflib.Streams.Open (Source, Max_Transfer => 0);
   Outcome := Giflib.Streams.Read_Exact (Source, Target (1 .. 1));
   Assert (Outcome.First_Error.Code = Giflib.Errors.Source_Zero_Progress, "zero progress was not rejected");
   Assert
     (Outcome.First_Error.Context.Source_Position.State =
        Giflib.Errors.Position_Available
      and then Outcome.First_Error.Context.Source_Position.Value = 0,
      "zero source offset was not preserved as present");

   Giflib.Streams.Open (Source);
   Outcome := Giflib.Streams.Read_Exact (Source, Target);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Source_Unexpected_End, "truncated read has wrong error");
   Assert (Outcome.First_Error.Context.Expected = 4 and then Outcome.First_Error.Context.Actual = 3,
           "truncated read has wrong diagnostic counts");

   Outcome := Giflib.Streams.Read_Exact (Failed_Source, Target (1 .. 1));
   Assert (Outcome.First_Error.Code = Giflib.Errors.Source_Read_Failed, "source failure was not propagated");
end Source_EOF_Skip_And_Failures;

