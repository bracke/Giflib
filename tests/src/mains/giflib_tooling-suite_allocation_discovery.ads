with Ada.Containers.Indefinite_Ordered_Maps;
with Ada.Strings.Unbounded;

with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Suite_Flow;
with Giflib_Tooling.Suite_Source_Selection;

private package Giflib_Tooling.Suite_Allocation_Discovery is
   package Test_Allocation_Maps is new
     Ada.Containers.Indefinite_Ordered_Maps
       (Key_Type => String,
        Element_Type => Ada.Strings.Unbounded.Unbounded_String,
        "=" => Ada.Strings.Unbounded."=");

   function Discover
     (Selected : Giflib_Tooling.Suite_Source_Selection.Selected_Body;
      Items : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
      Map : Giflib_Tooling.Suite_Flow.Flow_Map)
      return Test_Allocation_Maps.Map;
end Giflib_Tooling.Suite_Allocation_Discovery;
