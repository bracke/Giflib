separate (Giflib.Testing.Test_Ownership_Failures)
procedure Owned_Array_Growth_Is_Transactional
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Object : Test_Array_Ownership.Handle;
   Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
   Fault : Giflib.Internal.Ownership.Fault_State;
   Outcome : Giflib.Internal.Ownership.Allocation_Outcome;
   Before : Giflib.Byte_Count;
begin
   Outcome := Test_Array_Ownership.Ensure
     (Object, Budget, Fault, First => 0, Last => 1, Maximum => 64);
   Assert
     (Outcome.Status = Giflib.Internal.Ownership.Allocation_Ready
      and then Test_Array_Ownership.Element (Object, 0) = 0
      and then Test_Array_Ownership.Element (Object, 1) = 0,
      "owned-array allocation exposed uninitialized capacity");
   Test_Array_Ownership.Set_Element (Object, 0, 7);
   Before := Giflib.Internal.Ownership.Used (Budget);
   Giflib.Internal.Ownership.Testing.Arm (Fault);
   Outcome := Test_Array_Ownership.Ensure
     (Object, Budget, Fault, First => 0, Last => 3, Maximum => 64);
   Assert
     (Outcome.Status = Giflib.Internal.Ownership.Allocation_Storage_Error
      and then Test_Array_Ownership.Length (Object) = 2
      and then Test_Array_Ownership.Element (Object, 0) = 7
      and then Giflib.Internal.Ownership.Used (Budget) = Before,
      "failed owned-array replacement changed storage or its ledger");
   Outcome := Test_Array_Ownership.Grow
     (Object, Budget, Fault, First => 0, Last => 3,
      Preserve => 1, Maximum => 64);
   Assert
     (Outcome.Status = Giflib.Internal.Ownership.Allocation_Ready
      and then Test_Array_Ownership.Element (Object, 0) = 7
      and then Test_Array_Ownership.Element (Object, 1) = 0
      and then Test_Array_Ownership.Element (Object, 3) = 0,
      "owned-array growth did not initialize unused capacity");
   Assert
     (Test_Array_Ownership.Release (Object, Budget),
      "owned-array initialized-capacity cleanup failed");
end Owned_Array_Growth_Is_Transactional;
