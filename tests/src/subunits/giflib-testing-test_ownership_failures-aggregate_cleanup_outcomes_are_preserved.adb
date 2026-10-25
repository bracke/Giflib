separate (Giflib.Testing.Test_Ownership_Failures)
procedure Aggregate_Cleanup_Outcomes_Are_Preserved
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   package Cleanup renames Giflib.Internal.Cleanup;
   package Aggregates renames Giflib.Internal.Resource_Cleanup;
   Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
   Requested : Cleanup.Cleanup_Status := Cleanup.Cleanup_Complete;

   function Report return Cleanup.Cleanup_Outcome is
     (Status => Requested);

   function Raise_From_Release return Cleanup.Cleanup_Outcome is
   begin
      raise Program_Error with "aggregate cleanup callback probe";
      return Cleanup.Success;
   end Raise_From_Release;
begin
   for Status in Cleanup.Cleanup_Status loop
      Requested := Status;
      declare
         Sticky : aliased Cleanup.Cleanup_Status := Cleanup.Cleanup_Complete;
      begin
         declare
            Guard : Aggregates.Guard (Budget'Access, Sticky'Access);
            procedure Try is new Aggregates.Attempt (Report);
         begin
            Try (Guard);
         end;
         Assert
           (Sticky = Status,
            "aggregate cleanup did not retain its first outcome");
      end;
   end loop;

   declare
      Sticky : aliased Cleanup.Cleanup_Status := Cleanup.Cleanup_Complete;
   begin
      declare
         Guard : Aggregates.Guard (Budget'Access, Sticky'Access);
         procedure Try is new Aggregates.Attempt (Raise_From_Release);
      begin
         Try (Guard);
      end;
      Assert
        (Sticky = Cleanup.Cleanup_Callback_Failed,
         "aggregate cleanup did not normalize a callback exception");
   end;

   declare
      Sticky : aliased Cleanup.Cleanup_Status := Cleanup.Cleanup_Complete;
   begin
      Requested := Cleanup.Cleanup_Borrow_Conflict;
      declare
         Guard : Aggregates.Guard (Budget'Access, Sticky'Access);
         procedure Try is new Aggregates.Attempt (Report);
      begin
         Try (Guard);
         Requested := Cleanup.Cleanup_Owner_Mismatch;
         Try (Guard);
      end;
      Assert
        (Sticky = Cleanup.Cleanup_Borrow_Conflict,
         "aggregate cleanup did not preserve its first failure");
   end;

   declare
      Accounting_Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
      Sticky : aliased Cleanup.Cleanup_Status := Cleanup.Cleanup_Complete;
      Reserved : Boolean;
   begin
      Giflib.Internal.Ownership.Try_Reserve
        (Accounting_Budget, Maximum => 1, Amount => 1, Accepted => Reserved);
      Assert (Reserved, "aggregate accounting test setup failed");
      declare
         Guard : Aggregates.Guard (Accounting_Budget'Access, Sticky'Access);
         pragma Unreferenced (Guard);
      begin
         null;
      end;
      Assert
        (Sticky = Cleanup.Cleanup_Accounting_Failed,
         "aggregate cleanup omitted ledger reconciliation");
      Assert
        (Giflib.Internal.Ownership.Release (Accounting_Budget, 1),
         "aggregate accounting test teardown failed");
   end;
end Aggregate_Cleanup_Outcomes_Are_Preserved;
