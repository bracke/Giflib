package Giflib_Tooling.Work_Budgets.Testing is
   function Can_Charge
     (Object : Budget; Amount : Natural := 1) return Boolean;
   function Can_Enter (Object : Budget) return Boolean;
   function Current_Depth (Object : Budget) return Natural;
   function Used (Object : Budget) return Natural;
   procedure Reach_Depth_Limit (Object : in out Budget);
end Giflib_Tooling.Work_Budgets.Testing;
