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

   function Warning_Capacity
     (Maximum_Warnings : Natural;
      Maximum_Diagnostics : Natural) return Natural
     with Post =>
       Warning_Capacity'Result =
         Natural'Min (Natural'Min (Maximum_Warnings, Maximum_Diagnostics), 256)
       and then Warning_Capacity'Result <= 256;

end Giflib.Internal.Session_Arithmetic;
