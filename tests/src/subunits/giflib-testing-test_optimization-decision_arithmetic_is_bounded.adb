separate (Giflib.Testing.Test_Optimization)
procedure Decision_Arithmetic_Is_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   package Arithmetic renames Giflib.Internal.Optimization_Arithmetic;
   Bounds : Arithmetic.Change_Bounds;
   Unsafe : Giflib.Frames.Graphic_Control := Giflib.Frames.Default_Control;
begin
   Bounds := Arithmetic.Include (Bounds, 5, 7);
   Bounds := Arithmetic.Include (Bounds, 2, 9);
   Assert (not Bounds.Empty
           and then Bounds.Min_X = 2 and then Bounds.Max_X = 5
           and then Bounds.Min_Y = 7 and then Bounds.Max_Y = 9
           and then Natural (Arithmetic.Width (Bounds)) = 4
           and then Natural (Arithmetic.Height (Bounds)) = 3,
           "optimizer change bounds are wrong");
   Assert (Arithmetic.Is_Safe
             (Giflib.Frames.Default_Control, Giflib.Frames.Default_Control, True),
           "safe optimizer controls were rejected");
   Unsafe.Disposal := 2;
   Assert (not Arithmetic.Is_Safe (Unsafe, Giflib.Frames.Default_Control, True),
           "unsafe optimizer controls were accepted");
   Assert (Arithmetic.Can_Merge_Delay (65_530, 5)
           and then Arithmetic.Merge_Delay (65_530, 5) = 65_535
           and then not Arithmetic.Can_Merge_Delay (65_535, 1),
           "optimizer delay bounds are wrong");
end Decision_Arithmetic_Is_Bounded;
