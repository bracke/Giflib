package Giflib_Platform_Services is
   type Memory_Metric (Available : Boolean := False) is record
      case Available is
         when True =>
            KiB : Natural;
         when False =>
            null;
      end case;
   end record;

   function Peak_Memory return Memory_Metric;
end Giflib_Platform_Services;
