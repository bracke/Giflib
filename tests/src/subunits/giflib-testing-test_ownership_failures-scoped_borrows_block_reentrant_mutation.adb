separate (Giflib.Testing.Test_Ownership_Failures)
procedure Scoped_Borrows_Block_Reentrant_Mutation
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   package Buffers renames Giflib.Internal.Owned_Buffers;
   Buffer : Buffers.Handle;
   Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
   Fault : Giflib.Internal.Ownership.Fault_State;
   Outcome : Giflib.Internal.Ownership.Allocation_Outcome;
   Release_Rejected : Boolean := False;
   Growth_Rejected : Boolean := False;
   Nested_Borrow_Rejected : Boolean := False;
   Value_Remained_Valid : Boolean := False;

   procedure Inspect (Value : Giflib.Streams.Byte_Array) is
      procedure Nested_Inspect (Nested : Giflib.Streams.Byte_Array) is
         pragma Unreferenced (Nested);
      begin
         null;
      end Nested_Inspect;
   begin
      begin
         Buffers.Query (Buffer, Nested_Inspect'Access);
      exception
         when others =>
            Nested_Borrow_Rejected := True;
      end;
      Release_Rejected := not Buffers.Release (Buffer, Budget);
      Outcome := Buffers.Ensure
        (Buffer, Budget, Fault, Required => 16, Maximum => 16);
      Growth_Rejected :=
        Outcome.Status = Giflib.Internal.Ownership.Allocation_Borrow_Error;
      Value_Remained_Valid := Value'Length = 8 and then Value (Value'First) = 0;
   end Inspect;
begin
   Outcome := Buffers.Ensure
     (Buffer, Budget, Fault, Required => 8, Maximum => 16);
   Assert
     (Outcome.Status = Giflib.Internal.Ownership.Allocation_Ready,
      "scoped-borrow setup failed");
   Buffers.Query (Buffer, Inspect'Access);
   Assert
     (Nested_Borrow_Rejected
      and then Release_Rejected
      and then Growth_Rejected
      and then Value_Remained_Valid
      and then not Buffers.Is_Borrowed (Buffer),
      "scoped borrow allowed reentrant storage mutation");
   Assert
     (Buffers.Release (Buffer, Budget),
      "scoped borrow was not released after the callback");
end Scoped_Borrows_Block_Reentrant_Mutation;
