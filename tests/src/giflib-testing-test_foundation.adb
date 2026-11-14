with AUnit.Assertions;

with Giflib.Capabilities;
with Giflib.Decoding;
with Giflib.Decoding.Testing;
with Giflib.Encoding;
with Giflib.Encoding.Testing;
with Giflib.Errors;
with Giflib.Images;
with Giflib.Internal.Budget_Arithmetic;
with Giflib.Internal.Session_Arithmetic;
with Giflib.Limits;
with Giflib.Palettes;
with Giflib.Quantization;
with Giflib.Results;
with Giflib.Streams;

package body Giflib.Testing.Test_Foundation is
   use AUnit.Assertions;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Errors.Position_State;
   use type Giflib.Errors.Warning_Code;
   use type Giflib.Errors.Warning_Severity;
   use type Giflib.Results.Status;

   procedure Capabilities_Are_Advertised (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Results_Preserve_First_Error (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Error_Identifiers_And_Context (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Defaults_Cover_Every_Limit (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Helpers_And_Warnings (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Session_Arithmetic_Is_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Controlled_Objects_Finalize_Automatically
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("foundation");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Capabilities_Are_Advertised'Access,
         "foundation.capabilities");
      Register_Routine (T, Results_Preserve_First_Error'Access, "foundation.results.status_and_error");
      Register_Routine (T, Error_Identifiers_And_Context'Access, "foundation.errors.context");
      Register_Routine (T, Defaults_Cover_Every_Limit'Access, "foundation.limits.defaults");
      Register_Routine (T, Helpers_And_Warnings'Access, "foundation.helpers_and_warnings");
      Register_Routine (T, Session_Arithmetic_Is_Bounded'Access,
                        "foundation.session_arithmetic");
      Register_Routine
        (T,
         Controlled_Objects_Finalize_Automatically'Access,
         "foundation.automatic_finalization");
   end Register_Tests;

   procedure Controlled_Objects_Finalize_Automatically
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Session_Arithmetic_Is_Bounded
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Capabilities_Are_Advertised
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Results_Preserve_First_Error (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Error_Identifiers_And_Context (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Defaults_Cover_Every_Limit (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Helpers_And_Warnings (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
end Giflib.Testing.Test_Foundation;
