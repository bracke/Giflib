with Giflib.Encoding.Resource_Management;
with Giflib.Encoding.Session_Transitions;
with Giflib.Internal.Lifecycle_Protocol;

private package Giflib.Encoding.Lifecycle_Sequence is new
  Giflib.Internal.Lifecycle_Protocol
    (Session => Encoder,
     Release => Resource_Management.Release,
     First_Cleanup_Status => Giflib.Encoding.First_Cleanup_Status,
     First_Error => Giflib.Encoding.First_Error,
     Commit_Failure => Session_Transitions.Fail_Session,
     Commit_Cancel => Session_Transitions.Cancel_Session,
     Record_Diagnostic => Session_Transitions.Record_Diagnostic,
     Commit_Finalize => Session_Transitions.Finalize_Session);
