separate (Giflib.Testing.Test_Container)
procedure Geometry_Arithmetic_Is_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   package Arithmetic renames Giflib.Internal.Geometry_Arithmetic;
   Full : constant Arithmetic.Rectangle_Analysis :=
     Arithmetic.Analyze_Rectangle (0, 0, 65_535, 65_535, 65_535, 65_535);
   Edge : constant Arithmetic.Rectangle_Analysis :=
     Arithmetic.Analyze_Rectangle (65_534, 65_534, 1, 1, 65_535, 65_535);
   Outside : constant Arithmetic.Rectangle_Analysis :=
     Arithmetic.Analyze_Rectangle (65_535, 65_535, 1, 1, 65_535, 65_535);
begin
   Assert (Full.Fits and then Full.Pixel_Area = 4_294_836_225,
           "maximum GIF canvas geometry is wrong");
   Assert (Edge.Fits and then Edge.Right_Edge = 65_535 and then Edge.Bottom_Edge = 65_535,
           "rectangle touching the canvas edge was rejected");
   Assert (not Outside.Fits
           and then Outside.Right_Edge = 65_536
           and then Outside.Bottom_Edge = 65_536,
           "out-of-bounds rectangle was accepted");
end Geometry_Arithmetic_Is_Bounded;
