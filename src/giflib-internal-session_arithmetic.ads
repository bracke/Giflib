package Giflib.Internal.Session_Arithmetic
  with Preelaborate, SPARK_Mode
is
   function Has_Natural_Capacity
     (Current : Natural;
      Maximum : Natural;
      Additional : Natural) return Boolean
     with Post =>
       Has_Natural_Capacity'Result =
         (Current <= Maximum and then Additional <= Maximum - Current);

end Giflib.Internal.Session_Arithmetic;
