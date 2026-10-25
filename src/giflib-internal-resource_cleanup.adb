package body Giflib.Internal.Resource_Cleanup is
   procedure Attempt (Object : in out Guard) is
      procedure Try_Release is new Ownership.Attempt_Release
        (Release_Operation);
   begin
      Try_Release (Object.Failed);
   end Attempt;

   overriding procedure Finalize (Object : in out Guard) is
   begin
      Object.Sticky_Failure.all :=
        Object.Sticky_Failure.all
        or else Object.Failed
        or else not Ownership.Healthy (Object.Budget.all);
   end Finalize;
end Giflib.Internal.Resource_Cleanup;
