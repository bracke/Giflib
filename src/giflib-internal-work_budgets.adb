with Giflib.Internal.Budget_Arithmetic;

package body Giflib.Internal.Work_Budgets
  with SPARK_Mode
is
   procedure Try_Charge
     (Object   : in out Meter;
      Amount   : Byte_Count;
      Accepted : out Boolean)
   is
   begin
      if Object.Exhausted then
         Accepted := False;
         return;
      end if;
      Budget_Arithmetic.Try_Charge
        (Object.Current,
         Object.Maximum,
         Amount,
         Accepted,
         Object.Last_Attempt);
      Object.Exhausted := Object.Exhausted or else not Accepted;
   end Try_Charge;

   function Used (Object : Meter) return Byte_Count is (Object.Current);

   function Attempted (Object : Meter) return Byte_Count is
     (Object.Last_Attempt);

   function Maximum (Object : Meter) return Byte_Count is (Object.Maximum);

   function Failed (Object : Meter) return Boolean is (Object.Exhausted);
end Giflib.Internal.Work_Budgets;
