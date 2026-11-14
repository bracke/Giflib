with Giflib.Encoding.Lifecycle_Sequence;

separate (Giflib.Encoding)
function Cancel (Object : in out Encoder) return Results.Result is
begin
   if State_Arithmetic.Can_Cancel (Object.Current_State) then
      if Object.Current_State /= Cancelled then
         return Lifecycle_Sequence.Release_And_Cancel (Object);
      end if;
      return Results.Success;
   elsif Object.Current_State = Failed then
      return Results.Failure (Object.Diagnostic);
   end if;
   return Failure_Handling.Invalid_State (Object);
end Cancel;
