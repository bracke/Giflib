with Giflib.Internal.Work_Budgets;

private package Giflib.Quantization.Workspace_Operations
  with Preelaborate
is
   function Ensure_Nearest_Cache
     (Context : in out Workspace;
      Constraints : Limits.Limit_Set) return Results.Result;

   function Ensure_Histogram
     (Context : in out Workspace;
      Constraints : Limits.Limit_Set) return Results.Result;

   function Ensure_Error_Buffer
     (Context : in out Workspace;
      Width : Image_Width;
      Constraints : Limits.Limit_Set) return Results.Result;

   function Work_Failure
     (Work : Internal.Work_Budgets.Meter) return Results.Result
     with Pre => Internal.Work_Budgets.Failed (Work);

   function Invariant_Failure return Results.Result;
end Giflib.Quantization.Workspace_Operations;
