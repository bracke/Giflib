package Giflib.Internal.Budget_Arithmetic with SPARK_Mode is
   pragma Pure;

   type Charge_Result is record
      Accepted : Boolean := False;
      Total : Byte_Count := 0;
      Attempted : Byte_Count := 0;
   end record;

   function Charge
     (Current : Byte_Count;
      Maximum : Byte_Count;
      Amount : Byte_Count) return Charge_Result
     with Post =>
       Charge'Result.Accepted =
         (Current <= Maximum and then Amount <= Maximum - Current)
       and then Charge'Result.Total =
         (if Charge'Result.Accepted then Current + Amount else Current)
       and then Charge'Result.Attempted =
         (if Amount <= Byte_Count'Last - Current
          then Current + Amount
          else Byte_Count'Last);
end Giflib.Internal.Budget_Arithmetic;
