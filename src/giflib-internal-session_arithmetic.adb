package body Giflib.Internal.Session_Arithmetic
  with SPARK_Mode
is
   function Has_Natural_Capacity
     (Current : Natural;
      Maximum : Natural;
      Additional : Natural) return Boolean
   is (Current <= Maximum and then Additional <= Maximum - Current);

end Giflib.Internal.Session_Arithmetic;
