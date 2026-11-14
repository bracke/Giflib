separate (Giflib.Testing.Test_Ownership_Failures)
procedure Owned_Resources_Reject_Foreign_Ledgers
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   package Buffers renames Giflib.Internal.Owned_Buffers;
   type Test_Object is limited record
      Value : Giflib.Byte := 0;
   end record
     with No_Controlled_Parts => True;
   package Objects is new Giflib.Internal.Owned_Objects
     (Test_Object);
   Buffer : Buffers.Handle;
   Object : Objects.Handle;
   First_Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
   Second_Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
   Fault : Giflib.Internal.Ownership.Fault_State;
   Outcome : Giflib.Internal.Ownership.Allocation_Outcome;
begin
   Outcome := Buffers.Ensure
     (Buffer, First_Budget, Fault, Required => 8, Maximum => 8);
   Assert
     (Outcome.Status = Giflib.Internal.Ownership.Allocation_Ready,
      "owned buffer setup failed");
   Outcome := Buffers.Ensure
     (Buffer, Second_Budget, Fault, Required => 8, Maximum => 8);
   Assert
     (Outcome.Status = Giflib.Internal.Ownership.Allocation_Owner_Error
      and then Buffers.Is_Allocated (Buffer)
      and then Giflib.Internal.Ownership.Used (Second_Budget) = 0,
      "owned buffer accepted a foreign ledger");
   Assert
     (not Giflib.Internal.Cleanup.Succeeded
        (Buffers.Release (Buffer, Second_Budget))
      and then Buffers.Is_Allocated (Buffer)
      and then Giflib.Internal.Ownership.Used (First_Budget) = 8
      and then Giflib.Internal.Ownership.Used (Second_Budget) = 0,
      "foreign-ledger cleanup changed storage or a ledger");
   Assert
     (Giflib.Internal.Cleanup.Succeeded
        (Buffers.Release (Buffer, First_Budget))
      and then not Buffers.Is_Allocated (Buffer)
      and then Giflib.Internal.Ownership.Used (First_Budget) = 0,
      "owned buffer cleanup was not retryable with its owner");

   Outcome := Buffers.Ensure
     (Buffer, First_Budget, Fault, Required => 8, Maximum => 8);
   Assert
     (Outcome.Status = Giflib.Internal.Ownership.Allocation_Ready,
      "owned buffer cleanup-fault setup failed");
   Giflib.Internal.Ownership.Testing.Set_Used (First_Budget, 0);
   Assert
     (not Giflib.Internal.Cleanup.Succeeded
        (Buffers.Release (Buffer, First_Budget))
      and then not Buffers.Is_Allocated (Buffer),
      "owned buffer retained storage after a ledger mismatch");
   Giflib.Internal.Ownership.Testing.Set_Used (First_Budget, 0);

   Outcome := Objects.Ensure
     (Object,
      First_Budget,
      Fault,
      Maximum => Objects.Allocation_Bytes);
   Assert
     (Outcome.Status = Giflib.Internal.Ownership.Allocation_Ready,
      "owned object setup failed");
   Outcome := Objects.Ensure
     (Object,
      Second_Budget,
      Fault,
      Maximum => Objects.Allocation_Bytes);
   Assert
     (Outcome.Status = Giflib.Internal.Ownership.Allocation_Owner_Error
      and then Objects.Is_Allocated (Object),
      "owned object accepted a foreign ledger");
   Assert
     (not Giflib.Internal.Cleanup.Succeeded
        (Objects.Release (Object, Second_Budget))
      and then Objects.Is_Allocated (Object)
      and then Giflib.Internal.Ownership.Used (First_Budget)
        = Objects.Allocation_Bytes
      and then Giflib.Internal.Ownership.Used (Second_Budget) = 0,
      "foreign-ledger object cleanup changed storage or a ledger");
   Assert
     (Giflib.Internal.Cleanup.Succeeded
        (Objects.Release (Object, First_Budget))
      and then not Objects.Is_Allocated (Object)
      and then Giflib.Internal.Ownership.Used (First_Budget) = 0,
      "owned object cleanup was not retryable with its owner");
end Owned_Resources_Reject_Foreign_Ledgers;

