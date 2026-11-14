package body Giflib_Tooling.Work_Budgets.Testing is
   function Can_Charge
     (Object : Budget; Amount : Natural := 1) return Boolean is
     (Work_Budgets.Can_Charge (Object, Amount));

   function Can_Enter (Object : Budget) return Boolean is
     (Work_Budgets.Can_Enter (Object));

   function Current_Depth (Object : Budget) return Natural is
     (Object.Data.Depth);

   function Used (Object : Budget) return Natural is
     (Work_Budgets.Used (Object));

   procedure Reach_Depth_Limit (Object : in out Budget) is
   begin
      Object.Data.Depth := Maximum_Depth;
   end Reach_Depth_Limit;
end Giflib_Tooling.Work_Budgets.Testing;
