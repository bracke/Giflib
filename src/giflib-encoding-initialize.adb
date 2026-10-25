separate (Giflib.Encoding)
function Initialize
  (Object : in out Encoder;
   Options : Encode_Options := Default_Options;
   Constraints : Limits.Limit_Set := Limits.Default_Limits)
   return Results.Result
is
begin
   if not State_Arithmetic.Can_Initialize (Object.Current_State) then
      return Invalid_Transition (Object);
   end if;
   Resource_Management.Release (Object);
   if not Resource_Management.Cleanup_Succeeded (Object) then
      Session_Transitions.Fail_Session
        (Object, Errors.Make (Errors.Internal_Invariant_Failed));
      return Results.Failure (Object.Diagnostic);
   end if;
   Session_Transitions.Begin_Session (Object, Options, Constraints);
   return Results.Success;
end Initialize;
