separate (Giflib.Testing.Test_Allocation_Failures)
procedure Owned_Vector_Ownership_Is_Exact
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
   Foreign_Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
   Fault : Giflib.Internal.Ownership.Fault_State;
   Outcome : Giflib.Internal.Ownership.Allocation_Outcome;
   Vector : Test_Vector.Handle;
begin
   Outcome := Test_Vector.Ensure_Append
     (Vector, Budget, Fault, Maximum => 64);
   Assert
     (Outcome.Status = Giflib.Internal.Ownership.Allocation_Ready
      and then Test_Vector.Length (Vector) = 0
      and then Test_Vector.Capacity (Vector) = 2,
      "owned vector confused reserved capacity with logical length");
   Test_Vector.Append (Vector, 11);
   Test_Vector.Append (Vector, 12);
   Outcome := Test_Vector.Ensure_Append
     (Vector, Budget, Fault, Maximum => 64);
   Assert
     (Outcome.Status = Giflib.Internal.Ownership.Allocation_Ready
      and then Test_Vector.Length (Vector) = 2
      and then Test_Vector.Capacity (Vector) = 4
      and then Test_Vector.Element (Vector, 1) = 11
      and then Test_Vector.Element (Vector, 2) = 12,
      "owned vector growth changed its logical prefix");
   Test_Vector.Append (Vector, 13);
   Assert
     (Test_Vector.Length (Vector) = 3
      and then Test_Vector.Element (Vector, 3) = 13,
      "owned vector append did not advance logical length");
   Outcome := Test_Vector.Ensure_Append
     (Vector, Foreign_Budget, Fault, Maximum => 64);
   Assert
     (Outcome.Status = Giflib.Internal.Ownership.Allocation_Owner_Error
      and then Test_Vector.Length (Vector) = 3
      and then Giflib.Internal.Ownership.Used (Foreign_Budget) = 0,
      "owned vector accepted a foreign ledger through spare capacity");
   Assert
     (not Test_Vector.Release (Vector, Foreign_Budget)
      and then Test_Vector.Length (Vector) = 3
      and then Test_Vector.Element (Vector, 3) = 13,
      "foreign-ledger vector release changed logical contents");
   Assert
     (Test_Vector.Release (Vector, Budget)
      and then Test_Vector.Length (Vector) = 0,
      "owned vector cleanup did not reset logical length");
end Owned_Vector_Ownership_Is_Exact;
