separate (Giflib.Testing.Test_Ownership_Failures)
procedure Scoped_Borrows_Block_Reentrant_Mutation
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   package Buffers renames Giflib.Internal.Owned_Buffers;
   type Test_Object is limited record
      Value : Natural := 0;
   end record;
   package Objects is new Giflib.Internal.Owned_Objects (Test_Object);
   package Object_Results is new Objects.Result_Operations (Boolean);
   Buffer : Buffers.Handle;
   Object : Objects.Handle;
   Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
   Fault : Giflib.Internal.Ownership.Fault_State;
   Outcome : Giflib.Internal.Ownership.Allocation_Outcome;
   Buffer_Release : Giflib.Internal.Cleanup.Cleanup_Outcome;
   Growth_Rejected : Boolean := False;
   Nested_Borrow_Rejected : Boolean := False;
   Value_Remained_Valid : Boolean := False;
   Object_Release : Giflib.Internal.Cleanup.Cleanup_Outcome;
   Object_Exception_Propagated : Boolean := False;

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
         when Ada.Assertions.Assertion_Error | Program_Error =>
            Nested_Borrow_Rejected := True;
      end;
      Buffer_Release := Buffers.Release (Buffer, Budget);
      Outcome := Buffers.Ensure
        (Buffer, Budget, Fault, Required => 16, Maximum => 16);
      Growth_Rejected :=
        Outcome.Status = Giflib.Internal.Ownership.Allocation_Borrow_Error;
      Value_Remained_Valid := Value'Length = 8 and then Value (Value'First) = 0;
   end Inspect;

   function Update_Object (Value : in out Test_Object) return Boolean is
   begin
      Object_Release := Objects.Release (Object, Budget);
      Value.Value := 7;
      return Value.Value = 7;
   end Update_Object;

   procedure Raise_From_Object (Value : in out Test_Object) is
      pragma Unreferenced (Value);
   begin
      raise Constraint_Error with "borrow unwind probe";
   end Raise_From_Object;
begin
   Outcome := Buffers.Ensure
     (Buffer, Budget, Fault, Required => 8, Maximum => 16);
   Assert
     (Outcome.Status = Giflib.Internal.Ownership.Allocation_Ready,
      "scoped-borrow setup failed");
   Buffers.Query (Buffer, Inspect'Access);
   Assert
     (Nested_Borrow_Rejected
      and then Buffer_Release.Status =
        Giflib.Internal.Cleanup.Cleanup_Borrow_Conflict
      and then Growth_Rejected
      and then Value_Remained_Valid
      and then not Buffers.Is_Borrowed (Buffer),
      "scoped borrow allowed reentrant storage mutation");
   Assert
     (Giflib.Internal.Cleanup.Succeeded (Buffers.Release (Buffer, Budget)),
      "scoped borrow was not released after the callback");

   Outcome := Objects.Ensure (Object, Budget, Fault, Maximum => 16);
   Assert
     (Outcome.Status = Giflib.Internal.Ownership.Allocation_Ready,
      "owned-object borrow setup failed");
   Assert
     (Object_Results.Update (Object, Update_Object'Access)
      and then Object_Release.Status =
        Giflib.Internal.Cleanup.Cleanup_Borrow_Conflict,
      "result-returning borrow did not preserve callback status");
   begin
      Objects.Update (Object, Raise_From_Object'Access);
   exception
      when Constraint_Error => Object_Exception_Propagated := True;
   end;
   Assert
     (Object_Exception_Propagated
      and then not Objects.Is_Borrowed (Object)
      and then Giflib.Internal.Cleanup.Succeeded
        (Objects.Release (Object, Budget)),
      "owned-object borrow was not released during exceptional unwind");
end Scoped_Borrows_Block_Reentrant_Mutation;
