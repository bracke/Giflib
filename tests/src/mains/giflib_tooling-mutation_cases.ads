with Giflib_Tooling.Mutation_Types;

private package Giflib_Tooling.Mutation_Cases is
   subtype Mutation_Case is Giflib_Tooling.Mutation_Types.Mutation_Case;
   subtype Mutation_Case_Array is
     Giflib_Tooling.Mutation_Types.Mutation_Case_Array;
   function All_Cases return Mutation_Case_Array;
   procedure Apply (Item : Mutation_Case; Fixture : String);
end Giflib_Tooling.Mutation_Cases;
