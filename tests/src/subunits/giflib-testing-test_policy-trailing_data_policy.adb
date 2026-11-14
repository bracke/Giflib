separate (Giflib.Testing.Test_Policy)
procedure Trailing_Data_Policy (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Fixture : aliased constant Giflib.Streams.Byte_Array := Base_GIF & [99];
   Exact_Fixture : aliased constant Giflib.Streams.Byte_Array := Base_GIF;
   Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
   Over_Source : aliased Overreporting_Source (Exact_Fixture'Access);
   Decoder : Giflib.Decoding.Decoder (Source'Access);
   Over_Decoder : Giflib.Decoding.Decoder (Over_Source'Access);
   Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
   Pixel : Giflib.Streams.Byte_Array (1 .. 1);
   Warning : Giflib.Errors.Warning;
   Outcome : Giflib.Results.Result;
begin
   Giflib.Streams.Open (Source);
   Outcome := Giflib.Decoding.Initialize (Decoder);
   Reach_End (Decoder, Pixel, Outcome);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Trailing_Data,
           "strict mode accepted trailing data");

   Options.Strictness := Giflib.Compatible;
   Giflib.Streams.Open (Source);
   Outcome := Giflib.Decoding.Reset (Decoder, Options);
   Reach_End (Decoder, Pixel, Outcome);
   Assert (Giflib.Results.Succeeded (Outcome), "compatible mode rejected trailing data");
   Assert (Giflib.Decoding.Warning_Count (Decoder) = 1, "trailing warning was not recorded");
   Outcome := Giflib.Decoding.Warning_At (Decoder, 1, Warning);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Assert (Warning.Code = Giflib.Errors.Trailing_Data_Ignored,
           "trailing warning has wrong code");

   Options := Giflib.Decoding.Default_Options;
   Giflib.Streams.Open
     (Over_Source.Backing);
   Outcome := Giflib.Decoding.Initialize
     (Over_Decoder, Options);
   Reach_End (Over_Decoder, Pixel, Outcome);
   Assert
     (Outcome.First_Error.Code = Giflib.Errors.Internal_Invariant_Failed
      and then Outcome.First_Error.Context.Actual = 2,
      "trailing-data probe accepted an over-reported read count");
end Trailing_Data_Policy;
