with Giflib.Decoding.Resource_Management;
with Giflib.Decoding.Session_Transitions;
with Giflib.Internal.Lifecycle_Protocol;

private package Giflib.Decoding.Lifecycle_Sequence is new
  Giflib.Internal.Lifecycle_Protocol
    (Session => Decoder,
     Release => Resource_Management.Release,
     First_Cleanup_Status => Giflib.Decoding.First_Cleanup_Status,
     First_Error => Giflib.Decoding.First_Error,
     Commit_Failure => Session_Transitions.Fail_Session,
     Commit_Cancel => Session_Transitions.Cancel_Session,
     Record_Diagnostic => Session_Transitions.Record_Diagnostic,
     Commit_Finalize => Session_Transitions.Finalize_Session);
