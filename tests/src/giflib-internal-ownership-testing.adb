package body Giflib.Internal.Ownership.Testing is
   procedure Arm
     (State : in out Fault_State;
      Successful_Allocations : Natural := 0)
   is
   begin
      State.Value := Ownership_Arithmetic.Arm (Successful_Allocations);
   end Arm;

   procedure Disable (State : in out Fault_State) is
   begin
      State.Value := Ownership_Arithmetic.Disabled;
   end Disable;

   procedure Set_Used
     (Budget : in out Byte_Budget;
      Value : Byte_Count)
   is
   begin
      Budget.Used_Bytes := Value;
   end Set_Used;
end Giflib.Internal.Ownership.Testing;
