with Giflib.Errors;
with Giflib.Internal.Ownership;
with Giflib.Internal.Quantization_Buffer_Arithmetic;
with Giflib.Internal.Resource_Diagnostics;

package body Giflib.Quantization.Workspace_Operations is
   use type Internal.Ownership.Allocation_Status;
   package Buffer_Arithmetic renames
     Internal.Quantization_Buffer_Arithmetic;
   package Storage renames Internal.Quantization_Storage;

   function Allocation_Result
     (Constraints : Limits.Limit_Set;
      Outcome : Internal.Ownership.Allocation_Outcome) return Results.Result is
     (Results.Failure
        (Internal.Resource_Diagnostics.Allocation_Error
           (Outcome,
            Constraints.Max_Allocation_Bytes,
            Outcome.Attempted)));

   function Ensure_Nearest_Cache
     (Context : in out Workspace;
      Constraints : Limits.Limit_Set) return Results.Result
   is
      Outcome : Internal.Ownership.Allocation_Outcome;
   begin
      if Storage.Nearest_Cache_Allocated (Context.Resources) then
         return Results.Success;
      end if;
      Outcome := Storage.Ensure_Nearest_Cache
        (Context.Resources,
         Context.Allocation_Fault,
         Constraints.Max_Allocation_Bytes);
      return
        (if Outcome.Status = Internal.Ownership.Allocation_Ready
         then Results.Success else Allocation_Result (Constraints, Outcome));
   end Ensure_Nearest_Cache;

   function Ensure_Histogram
     (Context : in out Workspace;
      Constraints : Limits.Limit_Set) return Results.Result
   is
      Outcome : Internal.Ownership.Allocation_Outcome;
   begin
      if Storage.Histogram_Allocated (Context.Resources) then
         return Results.Success;
      end if;
      Outcome := Storage.Ensure_Histogram
        (Context.Resources,
         Context.Allocation_Fault,
         Constraints.Max_Allocation_Bytes);
      return
        (if Outcome.Status = Internal.Ownership.Allocation_Ready
         then Results.Success else Allocation_Result (Constraints, Outcome));
   end Ensure_Histogram;

   function Ensure_Error_Buffer
     (Context : in out Workspace;
      Width : Image_Width;
      Constraints : Limits.Limit_Set) return Results.Result
   is
      Required_Length : constant Positive :=
        Buffer_Arithmetic.Error_Buffer_Length (Width);
      Outcome : Internal.Ownership.Allocation_Outcome;
   begin
      if Storage.Error_Length (Context.Resources) >= Required_Length then
         return Results.Success;
      end if;
      Outcome := Storage.Ensure_Errors
        (Context.Resources,
         Context.Allocation_Fault,
         Last => Required_Length - 1,
         Maximum => Constraints.Max_Allocation_Bytes);
      return
        (if Outcome.Status = Internal.Ownership.Allocation_Ready
         then Results.Success else Allocation_Result (Constraints, Outcome));
   end Ensure_Error_Buffer;

   function Work_Failure
     (Work : Internal.Work_Budgets.Meter) return Results.Result is
     (Results.Failure
        (Errors.Make
           (Errors.Limit_Exceeded,
            Internal.Resource_Diagnostics.With_Work_Limit
              (Work, Quantization_Work_Limit))));

   function Invariant_Failure return Results.Result is
     (Results.Failure (Errors.Make (Errors.Internal_Invariant_Failed)));
end Giflib.Quantization.Workspace_Operations;
