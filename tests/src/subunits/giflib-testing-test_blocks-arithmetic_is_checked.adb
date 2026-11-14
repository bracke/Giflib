separate (Giflib.Testing.Test_Blocks)
procedure Arithmetic_Is_Checked (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   use Giflib.Testing.Checked_Arithmetic;
   Item : Count_Result;
   Budget : Giflib.Internal.Budget_Arithmetic.Charge_Result;
begin
   Item := Add (40, 2);
   Assert (Giflib.Results.Succeeded (Item.Outcome) and then Item.Value = 42, "checked add failed");
   Item := Add (Giflib.Byte_Count'Last, 1);
   Assert (Item.Outcome.First_Error.Code = Giflib.Errors.Integer_Overflow, "add overflow was accepted");
   Item := Multiply (6, 7);
   Assert (Giflib.Results.Succeeded (Item.Outcome) and then Item.Value = 42, "checked multiply failed");
   Item := Multiply (Giflib.Byte_Count'Last, 2);
   Assert (Item.Outcome.First_Error.Code = Giflib.Errors.Integer_Overflow,
           "multiply overflow was accepted");

   Budget := Giflib.Internal.Budget_Arithmetic.Charge (40, 50, 2);
   Assert (Budget.Accepted and then Budget.Total = 42 and then Budget.Attempted = 42,
           "bounded budget charge failed");
   Budget := Giflib.Internal.Budget_Arithmetic.Charge (40, 41, 2);
   Assert (not Budget.Accepted and then Budget.Total = 40 and then Budget.Attempted = 42,
           "over-limit budget charge was accepted");
   Budget := Giflib.Internal.Budget_Arithmetic.Charge (Giflib.Byte_Count'Last, Giflib.Byte_Count'Last, 1);
   Assert (not Budget.Accepted
           and then Budget.Total = Giflib.Byte_Count'Last
           and then Budget.Attempted = Giflib.Byte_Count'Last,
           "overflowing budget diagnostic was not saturated");
end Arithmetic_Is_Checked;
