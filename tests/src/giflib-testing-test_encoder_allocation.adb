with AUnit.Assertions;
with Giflib.Encoding;
with Giflib.Encoding.Testing;
with Giflib.Errors;
with Giflib.Images;
with Giflib.Palettes;
with Giflib.Quantization;
with Giflib.Results;
with Giflib.Streams;

package body Giflib.Testing.Test_Encoder_Allocation is
   use AUnit.Assertions;
   use type Giflib.Encoding.Encoder_State;
   use type Giflib.Errors.Error_Code;

   procedure Require_Allocation_Failure
     (Outcome : Giflib.Results.Result;
      Message : String);

   procedure Encoder_Allocation_Failures
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("encoder_allocation");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Encoder_Allocation_Failures'Access,
         "allocation_failures.encoder");
   end Register_Tests;

   procedure Require_Allocation_Failure
     (Outcome : Giflib.Results.Result;
      Message : String) is
   begin
      Assert
        (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded
         and then Outcome.First_Error.Context.Limit =
           Giflib.Allocation_Byte_Limit,
         Message);
   end Require_Allocation_Failure;
end Giflib.Testing.Test_Encoder_Allocation;
