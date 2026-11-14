with Giflib.Errors;
with Giflib.Internal.Cleanup;
with Giflib.Results;

generic
   type Session (<>) is limited private;
   with function Release
     (Object : in out Session) return Giflib.Internal.Cleanup.Cleanup_Outcome;
   with procedure Commit_Failure
     (Object : in out Session; Diagnostic : Giflib.Errors.Error);
   with function First_Error (Object : Session) return Giflib.Errors.Error;
   with function First_Cleanup_Status
     (Object : Session) return Giflib.Internal.Cleanup.Cleanup_Status;
package Giflib.Internal.Failure_Protocol
  with Preelaborate
is
   function Fail
     (Object : in out Session;
      Diagnostic : Giflib.Errors.Error) return Giflib.Results.Result;
end Giflib.Internal.Failure_Protocol;
