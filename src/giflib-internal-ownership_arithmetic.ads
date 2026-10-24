package Giflib.Internal.Ownership_Arithmetic
  with Pure, SPARK_Mode
is
   type Injection_State is record
      Enabled : Boolean;
      Remaining_Successes : Natural;
   end record;

   Disabled : constant Injection_State :=
     (Enabled => False, Remaining_Successes => 0);

   type Check_Result is record
      State : Injection_State;
      Raise_Error : Boolean;
   end record;

   function Arm (Successful_Allocations : Natural) return Injection_State
     with Post =>
       Arm'Result.Enabled
       and then Arm'Result.Remaining_Successes = Successful_Allocations;

   function Check (State : Injection_State) return Check_Result
     with Post =>
       (if not State.Enabled
        then Check'Result.State = State and then not Check'Result.Raise_Error
        elsif State.Remaining_Successes > 0
        then Check'Result.State.Enabled
          and then Check'Result.State.Remaining_Successes =
            State.Remaining_Successes - 1
          and then not Check'Result.Raise_Error
        else Check'Result.State = Disabled and then Check'Result.Raise_Error);
end Giflib.Internal.Ownership_Arithmetic;
