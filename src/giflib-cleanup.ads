package Giflib.Cleanup
  with Pure
is
   type Cleanup_Status is
     (Cleanup_Complete,
      Cleanup_Borrow_Conflict,
      Cleanup_Owner_Mismatch,
      Cleanup_Preflight_Refused,
      Cleanup_Callback_Failed,
      Cleanup_Accounting_Failed);
end Giflib.Cleanup;
