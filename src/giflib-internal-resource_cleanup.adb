package body Giflib.Internal.Resource_Cleanup is
   use type Cleanup.Cleanup_Status;

   procedure Attempt (Object : in out Guard) is
      Outcome : Cleanup.Cleanup_Outcome;
   begin
      Outcome := Release_Operation;
      if Object.Status = Cleanup.Cleanup_Complete
        and then not Cleanup.Succeeded (Outcome)
      then
         Object.Status := Outcome.Status;
      end if;
   exception
      when others =>
         if Object.Status = Cleanup.Cleanup_Complete then
            Object.Status := Cleanup.Cleanup_Callback_Failed;
         end if;
   end Attempt;

   overriding procedure Finalize (Object : in out Guard) is
   begin
      if Object.Sticky_Status.all = Cleanup.Cleanup_Complete then
         if Object.Status /= Cleanup.Cleanup_Complete then
            Object.Sticky_Status.all := Object.Status;
         elsif not Ownership.Healthy (Object.Budget.all)
           or else Ownership.Used (Object.Budget.all) /= 0
         then
            Object.Sticky_Status.all := Cleanup.Cleanup_Accounting_Failed;
         end if;
      end if;
   end Finalize;
end Giflib.Internal.Resource_Cleanup;
