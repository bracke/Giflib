package body Giflib.Internal.Budget_Arithmetic with SPARK_Mode is
   function Charge
     (Current : Byte_Count;
      Maximum : Byte_Count;
      Amount : Byte_Count) return Charge_Result
   is
   begin
      if Amount > Byte_Count'Last - Current then
         return
           (Accepted => False,
            Total => Current,
            Attempted => Byte_Count'Last);
      elsif Current > Maximum or else Amount > Maximum - Current then
         return
           (Accepted => False,
            Total => Current,
            Attempted => Current + Amount);
      else
         return
           (Accepted => True,
            Total => Current + Amount,
            Attempted => Current + Amount);
      end if;
   end Charge;

   procedure Try_Charge
     (Current : in out Byte_Count;
      Maximum : Byte_Count;
      Amount : Byte_Count;
      Accepted : out Boolean;
      Attempted : out Byte_Count)
   is
      Result : constant Charge_Result := Charge (Current, Maximum, Amount);
   begin
      Accepted := Result.Accepted;
      Attempted := Result.Attempted;
      if Accepted then
         Current := Result.Total;
      end if;
   end Try_Charge;
end Giflib.Internal.Budget_Arithmetic;
