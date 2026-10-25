package Giflib.Internal.Work_Budgets
  with Preelaborate, SPARK_Mode
is
   type Meter (Maximum : Byte_Count) is private;

   function Used (Object : Meter) return Byte_Count;
   function Attempted (Object : Meter) return Byte_Count;
   function Maximum (Object : Meter) return Byte_Count;
   function Failed (Object : Meter) return Boolean;

   procedure Try_Charge
     (Object   : in out Meter;
      Amount   : Byte_Count;
      Accepted : out Boolean)
     with Post =>
       (if Failed (Object'Old)
        then not Accepted
          and then Used (Object) = Used (Object'Old)
          and then Attempted (Object) = Attempted (Object'Old)
        elsif Accepted
        then Used (Object) = Used (Object'Old) + Amount
        else Used (Object) = Used (Object'Old) and then Failed (Object));

private
   type Meter (Maximum : Byte_Count) is record
      Current : Byte_Count := 0;
      Last_Attempt : Byte_Count := 0;
      Exhausted : Boolean := False;
   end record;
end Giflib.Internal.Work_Budgets;
