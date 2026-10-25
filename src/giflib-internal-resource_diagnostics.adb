package body Giflib.Internal.Resource_Diagnostics is
   function With_Work_Limit
     (Object : Work_Budgets.Meter;
      Kind : Limit_Kind;
      Base : Errors.Diagnostic_Context := (others => <>))
      return Errors.Diagnostic_Context
   is
      Result : Errors.Diagnostic_Context := Base;
   begin
      Result.Expected := Work_Budgets.Maximum (Object);
      Result.Actual := Work_Budgets.Attempted (Object);
      Result.Limit := Kind;
      return Result;
   end With_Work_Limit;

   function Allocation_Error
     (Outcome : Ownership.Allocation_Outcome;
      Maximum : Byte_Count;
      Attempted : Byte_Count;
      Base : Errors.Diagnostic_Context := (others => <>)) return Errors.Error
   is
      Context : Errors.Diagnostic_Context := Base;
   begin
      case Outcome.Status is
         when Ownership.Allocation_Owner_Error =>
            return Errors.Make (Errors.Internal_Invariant_Failed, Context);
         when Ownership.Allocation_Size_Error =>
            return Errors.Make (Errors.Integer_Overflow, Context);
         when Ownership.Allocation_Limit |
              Ownership.Allocation_Storage_Error =>
            Context.Expected := Maximum;
            Context.Actual := Attempted;
            Context.Limit := Allocation_Byte_Limit;
            return Errors.Make (Errors.Limit_Exceeded, Context);
         when Ownership.Allocation_Ready =>
            return Errors.Make (Errors.Internal_Invariant_Failed, Context);
      end case;
   end Allocation_Error;
end Giflib.Internal.Resource_Diagnostics;
