with Giflib.Decoding.Resource_Management;
with Giflib.Decoding.Session_Transitions;
with Giflib.Internal.Failure_Protocol;

private package Giflib.Decoding.Failure_Sequence is new
  Giflib.Internal.Failure_Protocol
    (Session => Decoder,
     Release => Resource_Management.Release,
     Commit_Failure => Session_Transitions.Fail_Session,
     First_Error => Giflib.Decoding.First_Error,
     First_Cleanup_Status => Giflib.Decoding.First_Cleanup_Status);
