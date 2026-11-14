with Giflib.Encoding.Resource_Management;
with Giflib.Encoding.Session_Transitions;
with Giflib.Internal.Failure_Protocol;

private package Giflib.Encoding.Failure_Sequence is new
  Giflib.Internal.Failure_Protocol
    (Session => Encoder,
     Release => Resource_Management.Release,
     Commit_Failure => Session_Transitions.Fail_Session,
     First_Error => Giflib.Encoding.First_Error,
     First_Cleanup_Status => Giflib.Encoding.First_Cleanup_Status);
