package body Giflib.Internal.Ownership_Arithmetic
  with SPARK_Mode
is
   function Arm (Successful_Allocations : Natural) return Injection_State is
     ((Enabled => True, Remaining_Successes => Successful_Allocations));

   function Check (State : Injection_State) return Check_Result is
   begin
      if not State.Enabled then
         return (State => State, Raise_Error => False);
      elsif State.Remaining_Successes > 0 then
         return
           (State =>
              (Enabled => True,
               Remaining_Successes => State.Remaining_Successes - 1),
            Raise_Error => False);
      else
         return (State => Disabled, Raise_Error => True);
      end if;
   end Check;
end Giflib.Internal.Ownership_Arithmetic;
