with Giflib.Results;

package Giflib.Testing.Assertions is
   procedure Require_Success
     (Outcome : Giflib.Results.Result;
      Message : String := "test setup operation failed");
end Giflib.Testing.Assertions;
