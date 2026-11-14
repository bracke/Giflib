with Giflib.Decoding.Lifecycle_Sequence;

separate (Giflib.Decoding)
function Cancel (Object : in out Decoder) return Results.Result is
begin
   if State_Arithmetic.Can_Cancel (Object.Current_State) then
      return Lifecycle_Sequence.Release_And_Cancel (Object);
   elsif Object.Current_State = Cancelled then
      return Results.Success;
   elsif Object.Current_State = Failed then
      return Results.Failure (Object.Diagnostic);
   else
      return Failure_Handling.Invalid_State (Object);
   end if;
end Cancel;
