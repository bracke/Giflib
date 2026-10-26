separate (Giflib.Encoding)
function Cancel (Object : in out Encoder) return Results.Result is
   Cleanup_Status : Quantization.Cleanup_Status;
begin
   if State_Arithmetic.Can_Cancel (Object.Current_State) then
      if Object.Current_State /= Cancelled then
         Cleanup_Status := Resource_Management.Release (Object);
         if Cleanup_Status /= Quantization.Cleanup_Complete then
            Session_Transitions.Fail_Session
              (Object, Errors.Make (Errors.Internal_Invariant_Failed));
            return Results.Failure (Object.Diagnostic);
         end if;
         Session_Transitions.Cancel_Session (Object);
      end if;
      return Results.Success;
   elsif Object.Current_State = Failed then
      return Results.Failure (Object.Diagnostic);
   end if;
   return Invalid_Transition (Object);
end Cancel;
