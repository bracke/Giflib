separate (Giflib.Testing.Test_Ownership_Failures)
procedure Owned_Array_Ranges_Are_Structured
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Object : Test_Array_Ownership.Handle;
   Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
   Fault : Giflib.Internal.Ownership.Fault_State;
   Outcome : Giflib.Internal.Ownership.Allocation_Outcome;
   Item : Giflib.Errors.Error;
begin
   Outcome := Test_Array_Ownership.Ensure
     (Object, Budget, Fault, First => 0, Last => Natural'Last,
      Maximum => Giflib.Byte_Count'Last);
   Assert
     (Outcome.Status = Giflib.Internal.Ownership.Allocation_Size_Error
      and then not Test_Array_Ownership.Is_Allocated (Object)
      and then Giflib.Internal.Ownership.Used (Budget) = 0,
      "unrepresentable array range did not return a structured failure");
   Item := Giflib.Internal.Resource_Diagnostics.Allocation_Error
     (Outcome, Giflib.Byte_Count'Last, Outcome.Attempted);
   Assert
     (Item.Code = Giflib.Errors.Integer_Overflow,
      "array range failure was translated incorrectly");
end Owned_Array_Ranges_Are_Structured;
