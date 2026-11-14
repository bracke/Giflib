with Ada.Strings.Unbounded;

with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Suite_Allocation_Discovery;
with Giflib_Tooling.Suite_Flow;
with Giflib_Tooling.Suite_Source_Selection;

private package Giflib_Tooling.Suite_Registration_Traversal is
   procedure Visit
     (Selected : Giflib_Tooling.Suite_Source_Selection.Selected_Body;
      Items : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
      Map : Giflib_Tooling.Suite_Flow.Flow_Map;
      Returned_Suite : Ada.Strings.Unbounded.Unbounded_String;
      Allocations :
        Giflib_Tooling.Suite_Allocation_Discovery.Test_Allocation_Maps.Map;
      Process : not null access procedure (Unit_Name : String));
end Giflib_Tooling.Suite_Registration_Traversal;
