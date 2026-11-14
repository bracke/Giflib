with Giflib.Encoding.Wire_Output;
with Giflib.Internal.Wire_Format;

separate (Giflib.Encoding)
function Finish (Object : in out Encoder) return Results.Result is
   Outcome : Results.Result;
   Flush_Error : Errors.Error;
begin
   if Object.Current_State = Completed then
      return Results.Success;
   elsif not State_Arithmetic.Can_Finish (Object.Current_State) then
      return Failure_Handling.Invalid_State (Object);
   end if;
   Outcome := Write_Header (Object);
   if Results.Succeeded (Outcome) then
      Outcome := Wire_Output.Write (Object, [1 => Internal.Wire_Format.Trailer]);
   end if;
   if not Results.Succeeded (Outcome) then
      return Failure_Handling.Fail (Object, Outcome.First_Error);
   end if;
   Flush_Error := Streams.Flush_Safely (Object.Output.all);
   if Errors.Is_Fatal (Flush_Error) then
      return Failure_Handling.Fail (Object, Flush_Error);
   end if;
   Session_Transitions.Complete_Session (Object);
   return Results.Success;
end Finish;
