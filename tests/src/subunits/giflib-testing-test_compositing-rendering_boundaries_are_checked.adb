separate (Giflib.Testing.Test_Compositing)
procedure Rendering_Boundaries_Are_Checked
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Canvas : Giflib.Streams.Byte_Array (1 .. 4) := [others => 0];
   Short : Giflib.Streams.Byte_Array (1 .. 3) := [others => 0];
   Oversized : Giflib.Streams.Byte_Array (1 .. 8) := [others => 0];
   Indices : constant Giflib.Streams.Byte_Array (1 .. 1) := [1 => 2];
   Palette : Giflib.Palettes.Palette;
   Rectangle : constant Giflib.Frames.Rectangle :=
     (Left => 0, Top => 0, Width => 1, Height => 1);
   Outcome : Giflib.Results.Result;
begin
   Palette.Length := 2;
   Outcome := Giflib.Internal.Compositing.Overlay
     (Canvas, 1, Rectangle, Indices, Palette,
      Giflib.Frames.Default_Control);
   Assert
     (Outcome.First_Error.Code = Giflib.Errors.Internal_Invariant_Failed,
      "compositor accepted an out-of-palette index");

   Outcome := Giflib.Internal.Disposal.Fill_Rectangle
     (Short, 1, Rectangle, (others => 0), 0);
   Assert
     (Outcome.First_Error.Code = Giflib.Errors.Internal_Invariant_Failed,
      "disposal accepted a short canvas");

   Outcome := Giflib.Internal.Disposal.Capture_Rectangle
     (Canvas, 1, Rectangle, Short);
   Assert
     (Outcome.First_Error.Code = Giflib.Errors.Internal_Invariant_Failed,
      "snapshot capture accepted a short target");

   Outcome := Giflib.Internal.Disposal.Capture_Rectangle
     (Canvas, 1, Rectangle, Oversized);
   Assert
     (Giflib.Results.Succeeded (Outcome),
      "snapshot capture rejected reusable grow-only storage");
end Rendering_Boundaries_Are_Checked;
