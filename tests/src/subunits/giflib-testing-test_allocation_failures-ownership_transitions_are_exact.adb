separate (Giflib.Testing.Test_Allocation_Failures)
procedure Ownership_Transitions_Are_Exact
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   package Arithmetic renames Giflib.Internal.Ownership_Arithmetic;
   State : constant Arithmetic.Injection_State := Arithmetic.Arm (2);
   Result : Arithmetic.Check_Result;
   Budget : Giflib.Internal.Ownership.Byte_Budget;
   Rollback_Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
   Rollback_Fault : Giflib.Internal.Ownership.Fault_State;
   Rollback_Outcome : Giflib.Internal.Ownership.Allocation_Outcome;
   Reserved : Boolean;
   Work : Giflib.Internal.Work_Budgets.Meter (6);
   Accepted : Boolean;
   Work_Context : Giflib.Errors.Diagnostic_Context;
   Cleanup_Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
   Cleanup_Failed : aliased Boolean := False;
   Residual_Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
   Residual_Failed : aliased Boolean := False;
   function Raising_Release return Boolean is
   begin
      raise Program_Error;
      return True;
   end Raising_Release;
   procedure Attempt_Raising_Release is new
     Giflib.Internal.Resource_Cleanup.Attempt (Raising_Release);
begin
   Result := Arithmetic.Check (State);
   Assert
     (not Result.Raise_Error and then Result.State.Enabled
      and then Result.State.Remaining_Successes = 1,
      "first injected allocation transition is wrong");
   Result := Arithmetic.Check (Result.State);
   Assert
     (not Result.Raise_Error and then Result.State.Enabled
      and then Result.State.Remaining_Successes = 0,
      "second injected allocation transition is wrong");
   Result := Arithmetic.Check (Result.State);
   Assert
     (Result.Raise_Error and then Result.State = Arithmetic.Disabled,
      "injected failure did not disable itself");
   Result := Arithmetic.Check (Result.State);
   Assert
     (not Result.Raise_Error and then Result.State = Arithmetic.Disabled,
      "disabled injection did not remain inert");
   Giflib.Internal.Ownership.Try_Reserve (Budget, 10, 6, Reserved);
   Assert
     (Giflib.Internal.Ownership.Storage_Bytes (System.Storage_Unit + 1) = 2
      and then Reserved,
      "allocation budget sizing or reservation is wrong");
   Giflib.Internal.Ownership.Try_Reserve (Budget, 10, 5, Reserved);
   Assert
     (Giflib.Internal.Ownership.Used (Budget) = 6 and then not Reserved,
      "allocation budget did not retain its charge");
   Assert
     (Giflib.Internal.Ownership.Release (Budget, 6)
      and then Giflib.Internal.Ownership.Used (Budget) = 0,
      "allocation budget release is unbalanced");
   Assert
     (not Giflib.Internal.Ownership.Release (Budget, 1)
      and then not Giflib.Internal.Ownership.Healthy (Budget),
      "ledger underflow did not leave a sticky cleanup fault");
   declare
      Ticket : Giflib.Internal.Ownership.Reservation (Rollback_Budget'Access);
   begin
      Rollback_Outcome := Giflib.Internal.Ownership.Reserve
        (Ticket, Rollback_Fault, 4, 4);
      Assert
        (Rollback_Outcome.Status = Giflib.Internal.Ownership.Allocation_Ready,
         "rollback test reservation failed");
      Giflib.Internal.Ownership.Testing.Set_Used (Rollback_Budget, 0);
   end;
   Assert
     (not Giflib.Internal.Ownership.Healthy (Rollback_Budget),
      "reservation finalizer discarded its rollback failure");
   Giflib.Internal.Work_Budgets.Try_Charge
     (Work, Amount => 6, Accepted => Accepted);
   Assert
     (Accepted and then Giflib.Internal.Work_Budgets.Used (Work) = 6
      and then Giflib.Internal.Work_Budgets.Attempted (Work) = 6,
      "shared work meter did not update its total");
   Giflib.Internal.Work_Budgets.Try_Charge
     (Work, Amount => 1, Accepted => Accepted);
   Assert
     (not Accepted and then Giflib.Internal.Work_Budgets.Used (Work) = 6
      and then Giflib.Internal.Work_Budgets.Attempted (Work) = 7
      and then Giflib.Internal.Work_Budgets.Failed (Work),
      "shared work-meter rejection changed its total");
   Giflib.Internal.Work_Budgets.Try_Charge
     (Work, Amount => 0, Accepted => Accepted);
   Assert
     (not Accepted and then Giflib.Internal.Work_Budgets.Used (Work) = 6
      and then Giflib.Internal.Work_Budgets.Attempted (Work) = 7,
      "exhausted work meter resumed or lost its first failure");
   Work_Context := Giflib.Internal.Resource_Diagnostics.With_Work_Limit
     (Work, Giflib.Optimization_Work_Limit);
   Assert
     (Work_Context.Expected = 6 and then Work_Context.Actual = 7
      and then Work_Context.Limit = Giflib.Optimization_Work_Limit,
      "shared work-meter diagnostic context is wrong");
   declare
      Guard : Giflib.Internal.Resource_Cleanup.Guard
        (Cleanup_Budget'Access, Cleanup_Failed'Access);
   begin
      Attempt_Raising_Release (Guard);
      Assert
        (not Cleanup_Failed,
         "cleanup guard reconciled before leaving its scope");
   end;
   Assert
     (Cleanup_Failed,
      "scope-bound cleanup did not retain a release exception");
   Giflib.Internal.Ownership.Try_Reserve
     (Residual_Budget, 1, 1, Reserved);
   declare
      Guard : Giflib.Internal.Resource_Cleanup.Guard
        (Residual_Budget'Access, Residual_Failed'Access);
      pragma Unreferenced (Guard);
   begin
      null;
   end;
   Assert
     (Reserved and then Residual_Failed,
      "cleanup guard accepted a healthy ledger with residual ownership");
   Assert
     (Giflib.Internal.Ownership.Release (Residual_Budget, 1),
      "residual-ledger test cleanup failed");
end Ownership_Transitions_Are_Exact;
