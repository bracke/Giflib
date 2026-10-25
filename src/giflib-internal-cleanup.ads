package Giflib.Internal.Cleanup
  with Preelaborate
is
   type Cleanup_Status is
     (Cleanup_Complete,
      Cleanup_Borrow_Conflict,
      Cleanup_Owner_Mismatch,
      Cleanup_Preflight_Refused,
      Cleanup_Callback_Failed,
      Cleanup_Accounting_Failed);

   type Cleanup_Outcome is record
      Status : Cleanup_Status := Cleanup_Complete;
   end record;

   Success : constant Cleanup_Outcome :=
     (Status => Cleanup_Complete);

   function Succeeded (Outcome : Cleanup_Outcome) return Boolean is
     (Outcome.Status = Cleanup_Complete);

end Giflib.Internal.Cleanup;
