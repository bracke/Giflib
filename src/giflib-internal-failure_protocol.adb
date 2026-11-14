package body Giflib.Internal.Failure_Protocol is
   use type Giflib.Internal.Cleanup.Cleanup_Status;

   function Fail
     (Object : in out Session;
      Diagnostic : Giflib.Errors.Error) return Giflib.Results.Result
   is
      Cleanup_Outcome : constant Giflib.Internal.Cleanup.Cleanup_Outcome :=
        Release (Object);
   begin
      Commit_Failure (Object, Diagnostic);
      pragma Assert
        (Giflib.Internal.Cleanup.Succeeded (Cleanup_Outcome)
         or else First_Cleanup_Status (Object) = Cleanup_Outcome.Status);
      return Giflib.Results.Failure (First_Error (Object));
   end Fail;
end Giflib.Internal.Failure_Protocol;
