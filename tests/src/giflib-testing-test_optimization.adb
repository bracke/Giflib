with AUnit.Assertions;

with Giflib.Errors;
with Giflib.Frames;
with Giflib.Internal.Optimization_Arithmetic;
with Giflib.Limits;
with Giflib.Optimization;
with Giflib.Results;
with Giflib.Streams;

package body Giflib.Testing.Test_Optimization is
   use AUnit.Assertions;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Optimization.Optimization_Action;
   use type Giflib.Streams.Byte_Array;

   procedure Trims_And_Extracts_Rectangles (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Merges_Redundant_Delays_Conservatively (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Rejects_Unsafe_And_Over_Budget (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Decision_Arithmetic_Is_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("optimization");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Trims_And_Extracts_Rectangles'Access,
                        "optimization.rectangle_and_transparent_interior");
      Register_Routine (T, Merges_Redundant_Delays_Conservatively'Access,
                        "optimization.redundant_delay_merge");
      Register_Routine (T, Rejects_Unsafe_And_Over_Budget'Access,
                        "optimization.disposal_and_budget_guards");
      Register_Routine (T, Decision_Arithmetic_Is_Bounded'Access,
                        "optimization.decision_arithmetic");
   end Register_Tests;

   procedure Decision_Arithmetic_Is_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Trims_And_Extracts_Rectangles (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Merges_Redundant_Delays_Conservatively
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Rejects_Unsafe_And_Over_Budget (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
end Giflib.Testing.Test_Optimization;
