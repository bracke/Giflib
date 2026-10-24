with AUnit.Assertions;

with Giflib;
with Giflib.Errors;
with Giflib.Images;
with Giflib.Limits;
with Giflib.Palettes;
with Giflib.Quantization;
with Giflib.Results;
with Giflib.Streams;

package body Giflib_Testing.Test_Quantization is
   use AUnit.Assertions;
   use type Giflib.Byte;
   use type Giflib.Byte_Count;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Limit_Kind;
   use type Giflib.Palette_Index;
   use type Giflib.Palettes.Palette;
   use type Giflib.Palettes.RGB_Color;
   use type Giflib.Streams.Byte_Array;

   procedure Validates_Image_Views (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Preserves_Exact_Colors (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Quantizes_Many_Colors_Deterministically (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Handles_Alpha_Fixed_Palettes_And_Dither (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Enforces_Quantization_Budgets (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("quantization");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Validates_Image_Views'Access, "images.view_validation");
      Register_Routine (T, Preserves_Exact_Colors'Access, "quantization.exact_palette");
      Register_Routine
        (T, Quantizes_Many_Colors_Deterministically'Access, "quantization.median_cut.deterministic");
      Register_Routine
        (T, Handles_Alpha_Fixed_Palettes_And_Dither'Access,
         "quantization.alpha_fixed_and_dither");
      Register_Routine (T, Enforces_Quantization_Budgets'Access, "quantization.budgets");
   end Register_Tests;

   procedure Validates_Image_Views (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Data : aliased constant Giflib.Streams.Byte_Array := [for I in 1 .. 14 => Giflib.Byte (I)];
      View : Giflib.Images.Image_View :=
        (Format => Giflib.RGB_24, Width => 2, Height => 2, Stride => 8,
         Accessible_Bytes => 14, Data => Data'Unchecked_Access);
      Required : Giflib.Byte_Count;
      Outcome : Giflib.Results.Result;
   begin
      Outcome := Giflib.Images.Required_Bytes (View, Required);
      Assert (Giflib.Results.Succeeded (Outcome) and then Required = 14,
              "padded image extent was calculated incorrectly");
      Outcome := Giflib.Images.Validate (View);
      Assert (Giflib.Results.Succeeded (Outcome), "valid padded view was rejected");
      View.Stride := 5;
      Outcome := Giflib.Images.Validate (View);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_Dimensions,
              "short row stride was accepted");
      View.Stride := 8;
      View.Accessible_Bytes := 13;
      Outcome := Giflib.Images.Validate (View);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_Dimensions,
              "short accessible extent was accepted");
   end Validates_Image_Views;

   procedure Preserves_Exact_Colors (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Data : aliased constant Giflib.Streams.Byte_Array :=
        [255, 0, 0, 0, 255, 0, 0, 0, 255];
      View : constant Giflib.Images.Image_View :=
        (Format => Giflib.RGB_24, Width => 3, Height => 1, Stride => 9,
         Accessible_Bytes => 9, Data => Data'Unchecked_Access);
      Indexed : Giflib.Streams.Byte_Array (1 .. 3);
      Palette : Giflib.Palettes.Palette;
      Transparent : Boolean;
      Transparent_Index : Giflib.Palette_Index;
      Outcome : Giflib.Results.Result;
   begin
      Outcome := Giflib.Quantization.Quantize
        (View, Indexed, Palette, Transparent, Transparent_Index);
      Assert (Giflib.Results.Succeeded (Outcome), "exact quantization failed");
      Assert (not Transparent and then Indexed = [0, 1, 2],
              "exact quantization changed color indices");
      Assert
        (Palette.Length = 3
         and then Palette.Colors (0) = (255, 0, 0)
         and then Palette.Colors (1) = (0, 255, 0)
         and then Palette.Colors (2) = (0, 0, 255),
         "exact palette did not preserve first-seen colors");
   end Preserves_Exact_Colors;

   procedure Quantizes_Many_Colors_Deterministically (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Data : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 17 * 17 * 3 => 0];
      View : Giflib.Images.Image_View;
      First, Second : Giflib.Streams.Byte_Array (1 .. 17 * 17);
      First_Palette, Second_Palette : Giflib.Palettes.Palette;
      First_Transparent, Second_Transparent : Boolean;
      First_Transparent_Index, Second_Transparent_Index : Giflib.Palette_Index;
      Options : Giflib.Quantization.Quantize_Options := Giflib.Quantization.Default_Options;
      Outcome : Giflib.Results.Result;
      Position : Natural := Data'First;
      Error_Sum : Long_Long_Integer := 0;
      Chosen : Giflib.Palettes.RGB_Color;
      Pixel : Natural := First'First;
   begin
      for Y in 0 .. 16 loop
         for X in 0 .. 16 loop
            Data (Position) := Giflib.Byte (X * 15);
            Data (Position + 1) := Giflib.Byte (Y * 15);
            Data (Position + 2) := Giflib.Byte ((X * 17 + Y) mod 256);
            Position := Position + 3;
         end loop;
      end loop;
      View :=
        (Format => Giflib.RGB_24, Width => 17, Height => 17, Stride => 51,
         Accessible_Bytes => Data'Length, Data => Data'Unchecked_Access);
      Options.Maximum_Colors := 16;
      Outcome := Giflib.Quantization.Quantize
        (View, First, First_Palette, First_Transparent, First_Transparent_Index, Options);
      Assert (Giflib.Results.Succeeded (Outcome), "median-cut quantization failed");
      Outcome := Giflib.Quantization.Quantize
        (View, Second, Second_Palette, Second_Transparent, Second_Transparent_Index, Options);
      Assert (Giflib.Results.Succeeded (Outcome), "repeat median-cut quantization failed");
      Assert (First = Second and then First_Palette = Second_Palette,
              "median-cut output was not deterministic");
      Assert (First_Palette.Length = 16 and then not First_Transparent,
              "median-cut palette size was wrong");
      Position := Data'First;
      for I in First'Range loop
         Pixel := Natural (First (I));
         Chosen := First_Palette.Colors (Giflib.Palette_Index (Pixel));
         Error_Sum := Error_Sum
           + (Long_Long_Integer (Data (Position)) - Long_Long_Integer (Chosen.Red)) ** 2
           + (Long_Long_Integer (Data (Position + 1)) - Long_Long_Integer (Chosen.Green)) ** 2
           + (Long_Long_Integer (Data (Position + 2)) - Long_Long_Integer (Chosen.Blue)) ** 2;
         Position := Position + 3;
      end loop;
      Assert (Error_Sum / Long_Long_Integer (First'Length * 3) < 4_000,
              "median-cut quality exceeded the RGB mean-square threshold");
   end Quantizes_Many_Colors_Deterministically;

   procedure Handles_Alpha_Fixed_Palettes_And_Dither
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      RGBA : aliased constant Giflib.Streams.Byte_Array := [255, 0, 0, 0, 0, 255, 0, 255];
      RGBA_View : constant Giflib.Images.Image_View :=
        (Format => Giflib.RGBA_32, Width => 2, Height => 1, Stride => 8,
         Accessible_Bytes => 8, Data => RGBA'Unchecked_Access);
      Gradient : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 16 * 3 => 0];
      Gradient_View : Giflib.Images.Image_View;
      Indexed : Giflib.Streams.Byte_Array (1 .. 2);
      Dithered, Repeated : Giflib.Streams.Byte_Array (1 .. 16);
      Palette, Repeated_Palette : Giflib.Palettes.Palette;
      Transparent, Repeated_Transparent : Boolean;
      Transparent_Index, Repeated_Index : Giflib.Palette_Index;
      Options : Giflib.Quantization.Quantize_Options := Giflib.Quantization.Default_Options;
      Outcome : Giflib.Results.Result;
   begin
      Options.Strategy := Giflib.Quantization.Use_Fixed_Palette;
      Options.Fixed_Palette.Length := 3;
      Options.Fixed_Palette.Colors (0) := (255, 0, 0);
      Options.Fixed_Palette.Colors (1) := (0, 255, 0);
      Options.Fixed_Palette.Colors (2) := (0, 0, 0);
      Options.Fixed_Transparent_Index := 2;
      Outcome := Giflib.Quantization.Quantize
        (RGBA_View, Indexed, Palette, Transparent, Transparent_Index, Options);
      Assert (Giflib.Results.Succeeded (Outcome)
              and then Transparent and then Transparent_Index = 2
              and then Indexed = [2, 1],
              "alpha threshold or fixed transparent palette mapping failed");

      for I in 0 .. 15 loop
         Gradient (I * 3 + 1) := Giflib.Byte (I * 17);
         Gradient (I * 3 + 2) := Giflib.Byte (I * 17);
         Gradient (I * 3 + 3) := Giflib.Byte (I * 17);
      end loop;
      Gradient_View :=
        (Format => Giflib.RGB_24, Width => 16, Height => 1, Stride => 48,
         Accessible_Bytes => 48, Data => Gradient'Unchecked_Access);
      Options := Giflib.Quantization.Default_Options;
      Options.Maximum_Colors := 2;
      Options.Dither := Giflib.Quantization.Floyd_Steinberg;
      Outcome := Giflib.Quantization.Quantize
        (Gradient_View, Dithered, Palette, Transparent, Transparent_Index, Options);
      Assert (Giflib.Results.Succeeded (Outcome), "Floyd-Steinberg quantization failed");
      Outcome := Giflib.Quantization.Quantize
        (Gradient_View, Repeated, Repeated_Palette, Repeated_Transparent, Repeated_Index, Options);
      Assert (Giflib.Results.Succeeded (Outcome)
              and then Dithered = Repeated and then Palette = Repeated_Palette,
              "Floyd-Steinberg output was not deterministic");
   end Handles_Alpha_Fixed_Palettes_And_Dither;

   procedure Enforces_Quantization_Budgets (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Data : aliased constant Giflib.Streams.Byte_Array := [0, 0, 0];
      View : constant Giflib.Images.Image_View :=
        (Format => Giflib.RGB_24, Width => 1, Height => 1, Stride => 3,
         Accessible_Bytes => 3, Data => Data'Unchecked_Access);
      Indexed : Giflib.Streams.Byte_Array (1 .. 1);
      Palette : Giflib.Palettes.Palette;
      Transparent : Boolean;
      Transparent_Index : Giflib.Palette_Index;
      Constraints : Giflib.Limits.Limit_Set := Giflib.Limits.Default_Limits;
      Outcome : Giflib.Results.Result;
   begin
      Constraints.Max_Quantization_Work := 0;
      Outcome := Giflib.Quantization.Quantize
        (View, Indexed, Palette, Transparent, Transparent_Index,
         Constraints => Constraints);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded
              and then Outcome.First_Error.Context.Limit = Giflib.Quantization_Work_Limit,
              "quantization work budget was not enforced");
      Constraints := Giflib.Limits.Default_Limits;
      Constraints.Max_Allocation_Bytes := 1;
      Outcome := Giflib.Quantization.Quantize
        (View, Indexed, Palette, Transparent, Transparent_Index,
         Constraints => Constraints);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded
              and then Outcome.First_Error.Context.Limit = Giflib.Allocation_Byte_Limit,
              "quantization allocation budget was not enforced");
   end Enforces_Quantization_Budgets;
end Giflib_Testing.Test_Quantization;
