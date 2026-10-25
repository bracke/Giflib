separate (Giflib.Testing.Test_Allocation_Failures)
procedure Workspace_Failures_Are_Structured
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   package Storage renames Giflib.Internal.Quantization_Storage;
   package Operations renames Storage.Operations;
   package Cache renames Storage.Cache_Operations;
   package Dither renames Storage.Dither_Operations;
   package Histogram renames Storage.Histogram_Operations;
   Object : Storage.Resources;
   Fault : Giflib.Internal.Ownership.Fault_State;
   Outcome : Giflib.Internal.Ownership.Allocation_Outcome;
   Missing_Work : Giflib.Internal.Work_Budgets.Meter (100_000);
   Cache_Work : Giflib.Internal.Work_Budgets.Meter (0);
   Histogram_Work : Giflib.Internal.Work_Budgets.Meter (0);
   Dither_Work : Giflib.Internal.Work_Budgets.Meter (0);
   Status : Operations.Operation_Status;
   Probe : Operations.Cache_Probe_Result;
   Color : Operations.Color_Outcome;
   Result : Giflib.Results.Result;
   Palette : Giflib.Palettes.Palette := (others => <>);
begin
   Status := Histogram.Reset (Object, Missing_Work);
   Assert
     (Status = Operations.Operation_Invariant_Failure
      and then not Giflib.Internal.Work_Budgets.Failed (Missing_Work),
      "missing quantization storage was reported as work exhaustion");
   Status := Histogram.Add_Sample (Object, 0);
   Assert
     (Status = Operations.Operation_Invariant_Failure,
      "missing histogram accepted a sample");
   Result := Histogram.Build_Median_Cut
     (Object, 0, 2, Missing_Work, Palette);
   Assert
     (not Giflib.Results.Succeeded (Result)
      and then Result.First_Error.Code =
        Giflib.Errors.Internal_Invariant_Failed,
      "missing histogram reached palette construction");
   Status := Cache.Reset (Object, Missing_Work);
   Probe := Cache.Probe (Object, 0);
   Assert
     (Status = Operations.Operation_Invariant_Failure
      and then Probe.Status = Operations.Operation_Invariant_Failure
      and then Cache.Store (Object, 0, 0, 0) =
        Operations.Operation_Invariant_Failure,
      "missing nearest cache accepted an operation");
   Status := Dither.Reset (Object, 18, Missing_Work);
   Color := Dither.Adjust (Object, (others => 0), 0, 0, 3);
   Assert
     (Status = Operations.Operation_Invariant_Failure
      and then Dither.Clear_Next_Row (Object, 0, 3) =
        Operations.Operation_Invariant_Failure
      and then Dither.Clear_Transparent (Object, 0, 0, 3) =
        Operations.Operation_Invariant_Failure
      and then Color.Status = Operations.Operation_Invariant_Failure
      and then Dither.Diffuse
        (Object, 0, 1, 0, 3, (others => 0), (others => 0)) =
          Operations.Operation_Invariant_Failure,
      "missing dither storage accepted an operation");
   Outcome := Storage.Ensure_Nearest_Cache
     (Object, Fault, Giflib.Byte_Count'Last);
   Assert
     (Outcome.Status = Giflib.Internal.Ownership.Allocation_Ready,
      "nearest-cache setup failed");
   Status := Cache.Reset (Object, Cache_Work);
   Assert
     (Status = Operations.Operation_Work_Limit
      and then Giflib.Internal.Work_Budgets.Failed (Cache_Work),
      "workspace work exhaustion was not recorded structurally");
   Outcome := Storage.Ensure_Histogram
     (Object, Fault, Giflib.Byte_Count'Last);
   Assert
     (Outcome.Status = Giflib.Internal.Ownership.Allocation_Ready,
      "histogram setup failed");
   Status := Histogram.Reset (Object, Histogram_Work);
   Assert
     (Status = Operations.Operation_Work_Limit
      and then Giflib.Internal.Work_Budgets.Failed (Histogram_Work),
      "histogram work exhaustion was not recorded structurally");
   Outcome := Storage.Ensure_Errors
     (Object, Fault, Last => 17, Maximum => Giflib.Byte_Count'Last);
   Assert
     (Outcome.Status = Giflib.Internal.Ownership.Allocation_Ready,
      "dither-buffer setup failed");
   Status := Dither.Reset (Object, 18, Dither_Work);
   Assert
     (Status = Operations.Operation_Work_Limit
      and then Giflib.Internal.Work_Budgets.Failed (Dither_Work),
      "dither work exhaustion was not recorded structurally");
   Storage.Release (Object);
   Assert
     (Storage.Is_Released (Object)
      and then Storage.Cleanup_Succeeded (Object),
      "workspace status test cleanup failed");
end Workspace_Failures_Are_Structured;
