separate (Giflib.Testing.Test_Policy)
procedure Safe_Missing_Trailer_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Fixture : aliased constant Giflib.Streams.Byte_Array := Base_GIF (Trailer => False);
   Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
   Decoder : Giflib.Decoding.Decoder (Source'Access);
   Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
   Pixel : Giflib.Streams.Byte_Array (1 .. 1);
   Warning : Giflib.Errors.Warning;
   Outcome : Giflib.Results.Result;
begin
   Options.Strictness := Giflib.Recover_When_Safe;
   Giflib.Streams.Open (Source, Max_Transfer => 1);
   Outcome := Giflib.Decoding.Initialize (Decoder, Options);
   Reach_End (Decoder, Pixel, Outcome);
   Assert (Giflib.Results.Succeeded (Outcome), "safe missing-trailer recovery failed");
   Assert (Giflib.Decoding.Warning_Count (Decoder) = 1, "recovery warning was not recorded");
   Outcome := Giflib.Decoding.Warning_At (Decoder, 1, Warning);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Assert (Warning.Code = Giflib.Errors.Recovery_Applied, "recovery warning has wrong code");
end Safe_Missing_Trailer_Recovery;
