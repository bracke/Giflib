package Giflib.Internal.Ownership.Testing is
   procedure Arm
     (State : in out Fault_State;
      Successful_Allocations : Natural := 0);

   procedure Disable (State : in out Fault_State);

   procedure Set_Used
     (Budget : in out Byte_Budget;
      Value : Byte_Count);
end Giflib.Internal.Ownership.Testing;
