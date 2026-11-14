separate (Giflib.Testing.Test_Foundation)
procedure Helpers_And_Warnings (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Left : Giflib.Palettes.Palette;
   Right : Giflib.Palettes.Palette;
   Context : constant Giflib.Errors.Diagnostic_Context :=
     (Source_Position => Giflib.Errors.Source_Position_At (7),
      Frame => Giflib.Errors.Frame_At (2),
      others => <>);
   Warning : constant Giflib.Errors.Warning :=
     Giflib.Errors.Make_Warning
       (Giflib.Errors.Recovery_Applied, Giflib.Errors.Recovery, Context);
   Code_Only : constant Giflib.Results.Result :=
     Giflib.Results.Failure (Giflib.Errors.Invalid_State);
begin
   Assert (Giflib.Images.Bytes_Per_Pixel (Giflib.Indexed_8) = 1
           and then Giflib.Images.Bytes_Per_Pixel (Giflib.RGB_24) = 3
           and then Giflib.Images.Bytes_Per_Pixel (Giflib.BGR_24) = 3
           and then Giflib.Images.Bytes_Per_Pixel (Giflib.RGBA_32) = 4
           and then Giflib.Images.Bytes_Per_Pixel (Giflib.BGRA_32) = 4,
           "pixel-format byte widths are wrong");

   Assert (Giflib.Palettes.Is_Encodable_Length (2)
           and then Giflib.Palettes.Is_Encodable_Length (256)
           and then not Giflib.Palettes.Is_Encodable_Length (0)
           and then not Giflib.Palettes.Is_Encodable_Length (3),
           "encodable palette lengths are wrong");
   Left.Length := 2;
   Left.Colors (0) := (1, 2, 3);
   Left.Colors (1) := (4, 5, 6);
   Right := Left;
   Right.Colors (2) := (7, 8, 9);
   Assert (Giflib.Palettes.Contains (Left, 1)
           and then not Giflib.Palettes.Contains (Left, 2)
           and then Giflib.Palettes.Same_Entries (Left, Right),
           "palette bounds or active-entry equality is wrong");
   Right.Colors (1) := (9, 9, 9);
   Assert (not Giflib.Palettes.Same_Entries (Left, Right),
           "different active palette entries compared equal");
   Right := Left;
   Right.Length := 1;
   Assert (not Giflib.Palettes.Same_Entries (Left, Right),
           "different palette lengths compared equal");

   for Code in Giflib.Errors.Warning_Code loop
      Assert (Giflib.Errors.Identifier_For (Code)'Length > 4,
              "empty or malformed warning identifier");
   end loop;
   Assert (Warning.Code = Giflib.Errors.Recovery_Applied
           and then Warning.Severity = Giflib.Errors.Recovery
           and then Warning.Context.Source_Position.Value = 7
           and then Warning.Context.Frame.Present
           and then Warning.Context.Frame.Value = 2,
           "warning construction lost severity or context");
   Assert (Code_Only.First_Error.Code = Giflib.Errors.Invalid_State,
           "code-only failure construction lost its error");
   Assert (not Giflib.Errors.Is_Fatal
             (Giflib.Errors.Make (Giflib.Errors.No_Error))
           and then Giflib.Errors.Is_Fatal
             (Giflib.Errors.Make (Giflib.Errors.Invalid_State)),
           "fatal-error classification is wrong");
end Helpers_And_Warnings;

