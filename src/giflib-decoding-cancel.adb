separate (Giflib.Decoding)
function Cancel (Object : in out Decoder) return Results.Result is
   Cleanup_Outcome : Internal.Cleanup.Cleanup_Outcome;
begin
   if State_Arithmetic.Can_Cancel (Object.Current_State) then
      Cleanup_Outcome := Resource_Management.Release (Object);
      if not Internal.Cleanup.Succeeded (Cleanup_Outcome) then
         Session_Transitions.Fail_Session
           (Object, Errors.Make (Errors.Internal_Invariant_Failed));
         return Results.Failure (Object.Diagnostic);
      end if;
      Session_Transitions.Cancel_Session (Object);
      return Results.Success;
   elsif Object.Current_State = Cancelled then
      return Results.Success;
   elsif Object.Current_State = Failed then
      return Results.Failure (Object.Diagnostic);
   else
      return Invalid_Transition (Object);
   end if;
end Cancel;
