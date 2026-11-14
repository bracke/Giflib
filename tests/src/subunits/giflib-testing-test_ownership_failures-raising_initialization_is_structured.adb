separate (Giflib.Testing.Test_Ownership_Failures)
procedure Raising_Initialization_Is_Structured
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Object : Raising_Objects.Handle;
   Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
   Fault : Giflib.Internal.Ownership.Fault_State;
   Outcome : Giflib.Internal.Ownership.Allocation_Outcome;
begin
   Outcome := Raising_Objects.Ensure
     (Object, Budget, Fault, Raising_Objects.Allocation_Bytes);
   Assert
     (Outcome.Status =
        Giflib.Internal.Ownership.Allocation_Initialization_Error
      and then not Raising_Objects.Is_Allocated (Object)
      and then Giflib.Internal.Ownership.Used (Budget) = 0,
      "raising default initialization was misclassified or retained its reservation");
end Raising_Initialization_Is_Structured;

