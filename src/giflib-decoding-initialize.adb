with Giflib.Decoding.Lifecycle_Sequence;

separate (Giflib.Decoding)
function Initialize
  (Object : in out Decoder;
   Options : Decode_Options := Default_Options;
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
   if not Failure_Handling.Input_Position_Of (Object).Available then
      Session_Transitions.Fail_Session
        (Object,
         Errors.Make
           (Errors.Source_Read_Failed,
            (Source_Position => (State => Errors.Position_Unavailable),
             others => <>)));
      return Results.Failure (Object.Diagnostic);
   end if;
   Session_Transitions.Begin_Session (Object, Options, Constraints);
   return Results.Success;
end Initialize;
