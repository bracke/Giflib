with AUnit.Assertions;
with Giflib.Errors;

package body Giflib.Testing.Assertions is
   procedure Require_Success
     (Outcome : Giflib.Results.Result;
      Message : String := "test setup operation failed")
   is
   begin
      AUnit.Assertions.Assert
        (Giflib.Results.Succeeded (Outcome),
         Message & ": "
         & Giflib.Errors.Identifier (Outcome.First_Error));
   end Require_Success;
end Giflib.Testing.Assertions;
