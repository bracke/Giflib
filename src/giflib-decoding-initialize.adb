separate (Giflib.Decoding)
function Initialize
  (Object : in out Decoder;
   Options : Decode_Options := Default_Options;
   Constraints : Limits.Limit_Set := Limits.Default_Limits)
   return Results.Result
is
   Cleanup_Outcome : Internal.Cleanup.Cleanup_Outcome;
begin
   if not State_Arithmetic.Can_Initialize (Object.Current_State) then
      return Invalid_Transition (Object);
   end if;
   Cleanup_Outcome := Resource_Management.Release (Object);
   if not Internal.Cleanup.Succeeded (Cleanup_Outcome) then
      Session_Transitions.Fail_Session
        (Object, Errors.Make (Errors.Internal_Invariant_Failed));
      return Results.Failure (Object.Diagnostic);
   end if;
   if not Input_Position (Object).Available then
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
