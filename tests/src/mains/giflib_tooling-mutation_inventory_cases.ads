private package Giflib_Tooling.Mutation_Inventory_Cases is
   procedure Add_Unchecked_Main (Fixture : String);
   procedure Remove_Declared_Main (Fixture : String);
   procedure Duplicate_Declared_Main (Fixture : String);
   procedure Add_Stale_Documented_Executable (Fixture : String);
   procedure Duplicate_Documented_Executable (Fixture : String);
   procedure Change_Main_Declaration (Fixture : String);
end Giflib_Tooling.Mutation_Inventory_Cases;
