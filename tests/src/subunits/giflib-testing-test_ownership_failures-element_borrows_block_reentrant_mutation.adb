separate (Giflib.Testing.Test_Ownership_Failures)
procedure Element_Borrows_Block_Reentrant_Mutation
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Vector : Cleanup_Elements.Handle;
   Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
   Foreign_Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
   Fault : Giflib.Internal.Ownership.Fault_State;
   Outcome : Giflib.Internal.Ownership.Allocation_Outcome;
   Cleanup : Giflib.Internal.Cleanup.Cleanup_Outcome;
   Index : Positive := 1;
   Nested_Query_Rejected : Boolean := False;
   Release_Rejected : Boolean := False;
   Append_Rejected : Boolean := False;
   Value_Observed : Boolean := False;
   Exception_Propagated : Boolean := False;

   procedure Inspect (Value : Cleanup_Test_Element) is
      Nested_Index : Positive := 1;
      procedure Nested_Inspect (Nested : Cleanup_Test_Element) is
         pragma Unreferenced (Nested);
      begin
         null;
      end Nested_Inspect;
   begin
      Value_Observed := Value.Value = 11;
      begin
         Cleanup_Elements.Query (Vector, Index, Nested_Inspect'Access);
      exception
         when Ada.Assertions.Assertion_Error | Program_Error =>
            Nested_Query_Rejected := True;
      end;
      Release_Rejected := not Giflib.Internal.Cleanup.Succeeded
        (Cleanup_Elements.Release (Vector, Budget));
      Outcome := Cleanup_Elements.Append_New
        (Vector, Budget, Fault, Maximum => 4_096, Index => Nested_Index);
      Append_Rejected := Outcome.Status =
        Giflib.Internal.Ownership.Allocation_Borrow_Error;
   end Inspect;

   procedure Raise_From_Query (Value : Cleanup_Test_Element) is
      pragma Unreferenced (Value);
   begin
      raise Constraint_Error with "element borrow unwind probe";
   end Raise_From_Query;
begin
   Released_Element_Contents := 0;
   Outcome := Cleanup_Elements.Append_New
     (Vector, Budget, Fault, Maximum => 4_096, Index => Index);
   Assert
     (Outcome.Status = Giflib.Internal.Ownership.Allocation_Ready,
      "owned-element-vector borrow setup failed");
   Cleanup_Elements.Update
     (Vector, Index, Initialize_Cleanup_Element'Access);
   Cleanup_Elements.Query (Vector, Index, Inspect'Access);
   Assert
     (Value_Observed
      and then Nested_Query_Rejected
      and then Release_Rejected
      and then Append_Rejected
      and then not Cleanup_Elements.Is_Borrowed (Vector),
      "owned-element-vector query allowed reentrant mutation");
   begin
      Cleanup_Elements.Query (Vector, Index, Raise_From_Query'Access);
   exception
      when Constraint_Error => Exception_Propagated := True;
   end;
   Assert
     (Exception_Propagated and then not Cleanup_Elements.Is_Borrowed (Vector),
      "element query borrow was not released during exceptional unwind");
   Cleanup := Cleanup_Elements.Release (Vector, Foreign_Budget);
   Assert
     (Cleanup.Status = Giflib.Internal.Cleanup.Cleanup_Owner_Mismatch
      and then Cleanup_Elements.Is_Allocated (Vector),
      "owned-element-vector accepted a foreign allocation ledger");
   Cleanup := Cleanup_Elements.Release (Vector, Budget);
   Assert
     (Giflib.Internal.Cleanup.Succeeded (Cleanup)
      and then Giflib.Internal.Ownership.Used (Budget) = 0,
      "owned-element-vector borrow test cleanup failed");
end Element_Borrows_Block_Reentrant_Mutation;
