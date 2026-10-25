with Giflib.Errors;
with Giflib.Results;

package Giflib.Internal.Checked_Arithmetic with SPARK_Mode is
   pragma Preelaborate;
   use type Errors.Error_Code;

   type Count_Result is record
      Outcome : Results.Result := Results.Success;
      Value : Byte_Count := 0;
   end record;

   function Add (Left, Right : Byte_Count) return Count_Result
     with Post =>
       (if Right <= Byte_Count'Last - Left then
           Results.Succeeded (Add'Result.Outcome)
           and then Add'Result.Value = Left + Right
        else
           not Results.Succeeded (Add'Result.Outcome)
           and then Add'Result.Outcome.First_Error.Code = Errors.Integer_Overflow
           and then Add'Result.Value = 0);

   function Multiply (Left, Right : Byte_Count) return Count_Result
     with Post =>
       (if Left = 0 or else Right <= Byte_Count'Last / Left then
           Results.Succeeded (Multiply'Result.Outcome)
           and then Multiply'Result.Value = Left * Right
        else
           not Results.Succeeded (Multiply'Result.Outcome)
           and then Multiply'Result.Outcome.First_Error.Code = Errors.Integer_Overflow
           and then Multiply'Result.Value = 0);
end Giflib.Internal.Checked_Arithmetic;
