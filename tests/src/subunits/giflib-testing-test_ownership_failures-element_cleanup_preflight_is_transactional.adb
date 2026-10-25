separate (Giflib.Testing.Test_Ownership_Failures)
procedure Element_Cleanup_Preflight_Is_Transactional
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Vector : Cleanup_Elements.Handle;
   Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
   Fault : Giflib.Internal.Ownership.Fault_State;
   Outcome : Giflib.Internal.Ownership.Allocation_Outcome;
   Cleanup : Giflib.Internal.Cleanup.Cleanup_Outcome;
   First_Index : Positive := 1;
   Second_Index : Positive := 1;
   Usage_Before_Refusal : Giflib.Byte_Count;
begin
   Released_Element_Contents := 0;
   Outcome := Cleanup_Elements.Append_New
     (Vector, Budget, Fault, Maximum => 4_096, Index => First_Index);
   Assert
     (Outcome.Status = Giflib.Internal.Ownership.Allocation_Ready,
      "preflight test first-element setup failed");
   Outcome := Cleanup_Elements.Append_New
     (Vector, Budget, Fault, Maximum => 4_096, Index => Second_Index);
   Assert
     (Outcome.Status = Giflib.Internal.Ownership.Allocation_Ready,
      "preflight test second-element setup failed");
   Cleanup_Elements.Update
     (Vector, Second_Index, Block_Element_Release'Access);
   Usage_Before_Refusal := Giflib.Internal.Ownership.Used (Budget);
   Cleanup := Cleanup_Elements.Release (Vector, Budget);
   Assert
     (Cleanup.Status = Giflib.Internal.Cleanup.Cleanup_Preflight_Refused
      and then Cleanup_Elements.Is_Allocated (Vector)
      and then Cleanup_Elements.Length (Vector) = 2
      and then Giflib.Internal.Ownership.Used (Budget) = Usage_Before_Refusal
      and then Released_Element_Contents = 0,
      "preflight refusal changed composite ownership");
   Cleanup_Elements.Update
     (Vector, Second_Index, Allow_Element_Release'Access);
   Cleanup_Elements.Update
     (Vector, First_Index, Arm_Element_Preflight_Exception'Access);
   Cleanup := Cleanup_Elements.Release (Vector, Budget);
   Assert
     (Cleanup.Status = Giflib.Internal.Cleanup.Cleanup_Callback_Failed
      and then Cleanup_Elements.Is_Allocated (Vector)
      and then Cleanup_Elements.Length (Vector) = 2
      and then Giflib.Internal.Ownership.Used (Budget) = Usage_Before_Refusal
      and then Released_Element_Contents = 0,
      "preflight exception changed composite ownership");
   Cleanup_Elements.Update
     (Vector, First_Index, Clear_Element_Preflight_Exception'Access);
   Cleanup := Cleanup_Elements.Release (Vector, Budget);
   Assert
     (Giflib.Internal.Cleanup.Succeeded (Cleanup)
      and then not Cleanup_Elements.Is_Allocated (Vector)
      and then Giflib.Internal.Ownership.Used (Budget) = 0
      and then Released_Element_Contents = 2,
      "preflight test cleanup failed");
end Element_Cleanup_Preflight_Is_Transactional;
