with Giflib.Errors;
with Giflib.Internal.Cleanup;
with Giflib.Results;

generic
   type Session (<>) is limited private;
   with function Release
     (Object : in out Session) return Giflib.Internal.Cleanup.Cleanup_Outcome;
   with function First_Cleanup_Status
     (Object : Session) return Giflib.Internal.Cleanup.Cleanup_Status;
   with function First_Error (Object : Session) return Giflib.Errors.Error;
   with procedure Commit_Failure
     (Object : in out Session; Diagnostic : Giflib.Errors.Error);
   with procedure Commit_Cancel (Object : in out Session);
   with procedure Record_Diagnostic
     (Object : in out Session; Diagnostic : Giflib.Errors.Error);
   with procedure Commit_Finalize (Object : in out Session);
package Giflib.Internal.Lifecycle_Protocol
  with Preelaborate
is
   function Prepare_Initialization
     (Object : in out Session) return Giflib.Results.Result;
   function Release_And_Cancel
     (Object : in out Session) return Giflib.Results.Result;
   procedure Finalize_Session (Object : in out Session);
end Giflib.Internal.Lifecycle_Protocol;
