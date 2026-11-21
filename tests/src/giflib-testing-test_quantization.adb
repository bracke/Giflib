with AUnit.Assertions;

with Giflib.Errors;
with Giflib.Images;
with Giflib.Internal.Quantization_Arithmetic;
with Giflib.Internal.Quantization_Buffer_Arithmetic;
with Giflib.Internal.Quantization_Histograms;
with Giflib.Internal.Quantization_Mapping;
with Giflib.Internal.Quantization_Palette;
with Giflib.Internal.Quantization_Pixels;
with Giflib.Internal.Work_Budgets;
with Giflib.Limits;
with Giflib.Palettes;
with Giflib.Quantization;
with Giflib.Quantization.Testing;
with Giflib.Results;
with Giflib.Streams;

package body Giflib.Testing.Test_Quantization is
   use AUnit.Assertions;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Palettes.Palette;
   use type Giflib.Palettes.RGB_Color;
   use type Giflib.Streams.Byte_Array;

   procedure Validates_Image_Views (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Preserves_Exact_Colors (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Quantizes_Many_Colors_Deterministically (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Handles_Alpha_Fixed_Palettes_And_Dither (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Handles_BGR_Channel_Orders (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Enforces_Quantization_Budgets (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Color_Arithmetic_Is_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Pixel_Access_Is_Checked (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Error_Buffer_Arithmetic_Is_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Workspace_Reuses_Storage (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Workspace_Respects_Dither_Mode (T : in out AUnit.Test_Cases.Test_Case'Class);

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
      Register_Routine
        (T, Handles_BGR_Channel_Orders'Access,
         "quantization.bgr_and_bgra");
      Register_Routine (T, Enforces_Quantization_Budgets'Access, "quantization.budgets");
      Register_Routine (T, Color_Arithmetic_Is_Bounded'Access,
                        "quantization.color_arithmetic");
      Register_Routine (T, Pixel_Access_Is_Checked'Access,
                        "quantization.pixel_access");
      Register_Routine (T, Error_Buffer_Arithmetic_Is_Bounded'Access,
                        "quantization.error_buffer_arithmetic");
      Register_Routine (T, Workspace_Reuses_Storage'Access,
                        "quantization.workspace_reuse");
      Register_Routine (T, Workspace_Respects_Dither_Mode'Access,
                        "quantization.workspace_dither_mode");
   end Register_Tests;

   procedure Workspace_Respects_Dither_Mode
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Workspace_Reuses_Storage
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Error_Buffer_Arithmetic_Is_Bounded
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Color_Arithmetic_Is_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Pixel_Access_Is_Checked
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Validates_Image_Views (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Preserves_Exact_Colors (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Quantizes_Many_Colors_Deterministically (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Handles_Alpha_Fixed_Palettes_And_Dither
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Handles_BGR_Channel_Orders
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Enforces_Quantization_Budgets (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
end Giflib.Testing.Test_Quantization;
