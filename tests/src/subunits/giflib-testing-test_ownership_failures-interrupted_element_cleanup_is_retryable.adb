separate (Giflib.Testing.Test_Ownership_Failures)
procedure Interrupted_Element_Cleanup_Is_Retryable
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
   Query_Rejected : Boolean := False;
   Update_Rejected : Boolean := False;

   procedure Observe (Value : Cleanup_Test_Element) is
      pragma Unreferenced (Value);
   begin
      null;
   end Observe;

   procedure Touch (Value : in out Cleanup_Test_Element) is
      pragma Unreferenced (Value);
   begin
      null;
   end Touch;
begin
   Released_Element_Contents := 0;
   Outcome := Cleanup_Elements.Append_New
     (Vector, Budget, Fault, Maximum => 4_096, Index => First_Index);
   Assert
     (Outcome.Status = Giflib.Internal.Ownership.Allocation_Ready,
      "retry test first-element setup failed");
   Outcome := Cleanup_Elements.Append_New
     (Vector, Budget, Fault, Maximum => 4_096, Index => Second_Index);
   Assert
     (Outcome.Status = Giflib.Internal.Ownership.Allocation_Ready,
      "retry test second-element setup failed");
   Cleanup_Elements.Update
     (Vector, Second_Index, Arm_Element_Cleanup_Exception'Access);
   Cleanup := Cleanup_Elements.Release (Vector, Budget);
   Assert
     (Cleanup.Status = Giflib.Internal.Cleanup.Cleanup_Callback_Failed
      and then Cleanup_Elements.Is_Allocated (Vector)
      and then Cleanup_Elements.Length (Vector) = 2
      and then Cleanup_Elements.Is_Cleanup_In_Progress (Vector)
      and then Released_Element_Contents = 2,
      "cleanup exception lost its retry checkpoint");
   Outcome := Cleanup_Elements.Append_New
     (Vector, Budget, Fault, Maximum => 4_096, Index => First_Index);
   Assert
     (Outcome.Status = Giflib.Internal.Ownership.Allocation_Borrow_Error
      and then Cleanup_Elements.Length (Vector) = 2,
      "interrupted cleanup allowed vector growth");
   begin
      Cleanup_Elements.Query (Vector, First_Index, Observe'Access);
   exception
      when Ada.Assertions.Assertion_Error | Program_Error =>
         Query_Rejected := True;
   end;
   begin
      Cleanup_Elements.Update (Vector, First_Index, Touch'Access);
   exception
      when Ada.Assertions.Assertion_Error | Program_Error =>
         Update_Rejected := True;
   end;
   Cleanup := Cleanup_Elements.Release (Vector, Budget);
   Assert
     (Query_Rejected
      and then Update_Rejected
      and then Giflib.Internal.Cleanup.Succeeded (Cleanup)
      and then not Cleanup_Elements.Is_Allocated (Vector)
      and then not Cleanup_Elements.Is_Cleanup_In_Progress (Vector)
      and then Giflib.Internal.Ownership.Used (Budget) = 0
      and then Released_Element_Contents = 3,
      "interrupted cleanup could not resume safely");
end Interrupted_Element_Cleanup_Is_Retryable;
