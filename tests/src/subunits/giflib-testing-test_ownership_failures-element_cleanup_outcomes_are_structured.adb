separate (Giflib.Testing.Test_Ownership_Failures)
procedure Element_Cleanup_Outcomes_Are_Structured
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
begin
   Released_Element_Contents := 0;
   Outcome := Cleanup_Elements.Append_New
     (Vector, Budget, Fault, Maximum => 4_096, Index => First_Index);
   Assert
     (Outcome.Status = Giflib.Internal.Ownership.Allocation_Ready,
      "cleanup-outcome first-element setup failed");
   Outcome := Cleanup_Elements.Append_New
     (Vector, Budget, Fault, Maximum => 4_096, Index => Second_Index);
   Assert
     (Outcome.Status = Giflib.Internal.Ownership.Allocation_Ready,
      "cleanup-outcome second-element setup failed");
   Cleanup_Elements.Update
     (Vector, First_Index, Report_Element_Cleanup_Failure'Access);
   Cleanup := Cleanup_Elements.Release (Vector, Budget);
   Assert
     (Cleanup.Status = Giflib.Internal.Cleanup.Cleanup_Callback_Failed
      and then not Cleanup_Elements.Is_Allocated (Vector)
      and then Giflib.Internal.Ownership.Used (Budget) = 0
      and then Released_Element_Contents = 2,
      "composite cleanup collapsed a nested failure outcome");
end Element_Cleanup_Outcomes_Are_Structured;
