package body Giflib.Internal.Resource_Cleanup is

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

   function Current_Outcome (Object : Guard) return Cleanup.Cleanup_Outcome is
     (if Object.Status /= Cleanup.Cleanup_Complete
      then (Status => Object.Status)
      elsif not Ownership.Healthy (Object.Budget.all)
        or else Ownership.Used (Object.Budget.all) /= 0
      then (Status => Cleanup.Cleanup_Accounting_Failed)
      else Cleanup.Success);

   overriding procedure Finalize (Object : in out Guard) is
   begin
      if Object.Sticky_Status.all = Cleanup.Cleanup_Complete then
         declare
            Outcome : constant Cleanup.Cleanup_Outcome :=
              Current_Outcome (Object);
         begin
            if not Cleanup.Succeeded (Outcome) then
               Object.Sticky_Status.all := Outcome.Status;
            end if;
         end;
      end if;
   end Finalize;
end Giflib.Internal.Resource_Cleanup;
