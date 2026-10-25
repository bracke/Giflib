separate (Giflib.Decoding)
function Reset
  (Object : in out Decoder;
   Options : Decode_Options := Default_Options;
   Constraints : Limits.Limit_Set := Limits.Default_Limits)
   return Results.Result
is
begin
   Session_Transitions.Reset_Session (Object);
   return Initialize (Object, Options, Constraints);
end Reset;
