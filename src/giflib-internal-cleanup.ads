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

   function From_Release
     (Released : Boolean;
      Still_Allocated : Boolean) return Cleanup_Outcome is
     (if Released
      then Success
      elsif Still_Allocated
      then (Status => Cleanup_Owner_Mismatch)
      else (Status => Cleanup_Accounting_Failed));
end Giflib.Internal.Cleanup;
