with Giflib.Internal.Work_Budgets;

private package Giflib.Quantization.Palette_Building
  with Preelaborate
is
   type Prepared_Palette is record
      Value : Palettes.Palette := (others => <>);
      Has_Transparency : Boolean := False;
      Transparent_Index : Palette_Index := 0;
      Generated_Start : Natural range 0 .. 1 := 0;
   end record;

   function Build
     (Context : in out Workspace;
      Source : Images.Image_View;
      Options : Quantize_Options;
      Constraints : Limits.Limit_Set;
      Work : in out Internal.Work_Budgets.Meter;
      Prepared : out Prepared_Palette) return Results.Result;
end Giflib.Quantization.Palette_Building;
