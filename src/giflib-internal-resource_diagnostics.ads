with Giflib.Errors;
with Giflib.Internal.Ownership;
with Giflib.Internal.Work_Budgets;

package Giflib.Internal.Resource_Diagnostics is
   pragma Preelaborate;
   use type Ownership.Allocation_Status;

   function With_Work_Limit
     (Object : Work_Budgets.Meter;
      Kind : Limit_Kind;
      Base : Errors.Diagnostic_Context := (others => <>))
      return Errors.Diagnostic_Context
     with Pre => Work_Budgets.Failed (Object);

   function Allocation_Error
     (Outcome : Ownership.Allocation_Outcome;
      Maximum : Byte_Count;
      Attempted : Byte_Count;
      Base : Errors.Diagnostic_Context := (others => <>)) return Errors.Error
     with Pre => Outcome.Status /= Ownership.Allocation_Ready;
end Giflib.Internal.Resource_Diagnostics;
