with Giflib.Encoding.Lifecycle_Sequence;

separate (Giflib.Encoding)
function Initialize
  (Object : in out Encoder;
   Options : Encode_Options := Default_Options;
   Constraints : Limits.Limit_Set := Limits.Default_Limits)
   return Results.Result
is
   Outcome : Results.Result;
begin
   if not State_Arithmetic.Can_Initialize (Object.Current_State) then
      return Failure_Handling.Invalid_State (Object);
   end if;
   Outcome := Lifecycle_Sequence.Prepare_Initialization (Object);
   if not Results.Succeeded (Outcome) then
      return Outcome;
   end if;
   Session_Transitions.Begin_Session (Object, Options, Constraints);
   return Results.Success;
end Initialize;
