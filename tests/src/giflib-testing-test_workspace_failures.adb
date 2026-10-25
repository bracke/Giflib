with AUnit.Assertions;
with Giflib.Errors;
with Giflib.Internal.Ownership;
with Giflib.Internal.Quantization_Storage;
with Giflib.Internal.Quantization_Storage.Cache_Operations;
with Giflib.Internal.Quantization_Storage.Dither_Operations;
with Giflib.Internal.Quantization_Storage.Histogram_Operations;
with Giflib.Internal.Quantization_Storage.Outcomes;
with Giflib.Internal.Work_Budgets;
with Giflib.Palettes;
with Giflib.Results;

package body Giflib.Testing.Test_Workspace_Failures is
   use AUnit.Assertions;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Internal.Ownership.Allocation_Status;
   use type
     Giflib.Internal.Quantization_Storage.Outcomes.Budgeted_Status;
   use type Giflib.Internal.Quantization_Storage.Outcomes.Storage_Status;

   procedure Workspace_Failures_Are_Structured
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("workspace_failures");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Workspace_Failures_Are_Structured'Access,
         "allocation_failures.workspace_status");
   end Register_Tests;
end Giflib.Testing.Test_Workspace_Failures;
