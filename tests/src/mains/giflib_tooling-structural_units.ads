with Giflib_Tooling.Source_Events;
with Giflib_Tooling.Model_Storage_Budgets;
with Giflib_Tooling.Source_Units;
with Giflib_Tooling.Work_Budgets;

private package Giflib_Tooling.Structural_Units is
   package Events renames Giflib_Tooling.Source_Events;
   package Units renames Giflib_Tooling.Source_Units;
   package Budgets renames Giflib_Tooling.Work_Budgets;

   procedure Derive
     (Events : Giflib_Tooling.Source_Events.Structural_Event_Vectors.Vector;
      Units : out Giflib_Tooling.Source_Units.Program_Unit_Vectors.Vector;
      Maximum_Units : Natural;
      Budget : in out Budgets.Budget;
      Storage : in out Giflib_Tooling.Model_Storage_Budgets.Budget);
end Giflib_Tooling.Structural_Units;
