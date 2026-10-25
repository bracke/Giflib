with AUnit.Assertions;

with Giflib.Errors;
with Giflib.Images;
with Giflib.Internal.Quantization_Arithmetic;
with Giflib.Internal.Quantization_Buffer_Arithmetic;
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
   is
      pragma Unreferenced (T);
      Narrow_Data : aliased constant Giflib.Streams.Byte_Array :=
        [0, 0, 0, 255, 255, 255];
      Wide_Data : aliased constant Giflib.Streams.Byte_Array :=
        [0, 0, 0, 85, 85, 85, 170, 170, 170, 255, 255, 255];
      Narrow_View : constant Giflib.Images.Image_View :=
        (Format => Giflib.RGB_24, Width => 2, Height => 1, Stride => 6,
         Accessible_Bytes => 6, Data => Narrow_Data'Access);
      Wide_View : constant Giflib.Images.Image_View :=
        (Format => Giflib.RGB_24, Width => 4, Height => 1, Stride => 12,
         Accessible_Bytes => 12, Data => Wide_Data'Access);
      Context : Giflib.Quantization.Workspace;
      Narrow : Giflib.Streams.Byte_Array (1 .. 2);
      Reused, Fresh : Giflib.Streams.Byte_Array (1 .. 4);
      Quantized, Fresh_Quantized : Giflib.Quantization.Quantization_Result;
      Dither_Options : Giflib.Quantization.Quantize_Options :=
        Giflib.Quantization.Default_Options;
      Outcome : Giflib.Results.Result;
   begin
      Dither_Options.Palette.Maximum_Colors := 2;
      Dither_Options.Dither := Giflib.Quantization.Floyd_Steinberg;
      Outcome := Giflib.Quantization.Quantize
        (Context, Narrow_View, Narrow, Quantized, Dither_Options);
      Assert (Giflib.Results.Succeeded (Outcome),
              "initial dithered workspace quantization failed");

      Outcome := Giflib.Quantization.Quantize
        (Context, Wide_View, Reused, Quantized);
      Assert (Giflib.Results.Succeeded (Outcome),
              "retained dither storage affected a no-dither call");
      Outcome := Giflib.Quantization.Quantize
        (Wide_View, Fresh, Fresh_Quantized);
      Assert
        (Giflib.Results.Succeeded (Outcome)
         and then Reused = Fresh
         and then Quantized.Palette = Fresh_Quantized.Palette
         and then Quantized.Transparency.Present =
           Fresh_Quantized.Transparency.Present,
         "workspace reuse changed no-dither output");
      Giflib.Quantization.Finalize (Context);
   exception
      when others =>
         Giflib.Quantization.Finalize (Context);
         raise;
   end Workspace_Respects_Dither_Mode;

   procedure Workspace_Reuses_Storage
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Data : aliased constant Giflib.Streams.Byte_Array :=
        [0, 0, 0, 255, 255, 255];
      View : constant Giflib.Images.Image_View :=
        (Format => Giflib.RGB_24, Width => 2, Height => 1, Stride => 6,
         Accessible_Bytes => 6, Data => Data'Access);
      Context : Giflib.Quantization.Workspace;
      Indexed : Giflib.Streams.Byte_Array (1 .. 2);
      Quantized : Giflib.Quantization.Quantization_Result;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Quantization.Testing.Disable_Failure_Injection (Context);
      Outcome := Giflib.Quantization.Quantize
        (Context, View, Indexed, Quantized);
      Assert (Giflib.Results.Succeeded (Outcome)
              and then Giflib.Quantization.Allocated_Bytes (Context) > 0,
              "quantization workspace was not populated");
      Giflib.Quantization.Testing.Inject_Storage_Error_After (Context);
      Outcome := Giflib.Quantization.Quantize
        (Context, View, Indexed, Quantized);
      Assert (Giflib.Results.Succeeded (Outcome),
              "reused quantization workspace allocated again");
      Giflib.Quantization.Testing.Disable_Failure_Injection (Context);
      Giflib.Quantization.Finalize (Context);
      Assert (Giflib.Quantization.Allocated_Bytes (Context) = 0,
              "quantization workspace finalization retained storage");
   exception
      when others =>
         Giflib.Quantization.Testing.Disable_Failure_Injection (Context);
         Giflib.Quantization.Finalize (Context);
         raise;
   end Workspace_Reuses_Storage;

   procedure Error_Buffer_Arithmetic_Is_Bounded
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      package Arithmetic renames Giflib.Internal.Quantization_Buffer_Arithmetic;
      Span : constant Arithmetic.Error_Span := Arithmetic.Span_Of (65_535);
      Last : constant Natural :=
        Arithmetic.Error_Index (1, 2, Natural (Span) - 1, Span);
   begin
      Assert (Span = 65_537, "maximum dither span is wrong");
      Assert
        (Arithmetic.Error_Buffer_Length (65_535) = 393_222
         and then Last = 393_221,
         "maximum dither buffer index is wrong");
      Assert
        (Arithmetic.Allocation_Bytes (65_535, Long_Integer'Size / 8)
           = Giflib.Byte_Count (393_222 * (Long_Integer'Size / 8)),
         "dither allocation size is wrong");
   end Error_Buffer_Arithmetic_Is_Bounded;

   procedure Color_Arithmetic_Is_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      package Arithmetic renames Giflib.Internal.Quantization_Arithmetic;
      White_Cell : constant Arithmetic.Histogram_Index :=
        Arithmetic.Histogram_Of ((255, 255, 255));
   begin
      Assert (Arithmetic.Histogram_Of ((0, 0, 0)) = 0 and then White_Cell = 32_767,
              "color histogram endpoint is wrong");
      Assert (Arithmetic.Red_Bucket (White_Cell) = 31
              and then Arithmetic.Green_Bucket (White_Cell) = 31
              and then Arithmetic.Blue_Bucket (White_Cell) = 31,
              "histogram color decomposition is wrong");
      Assert (Arithmetic.Clamp (Long_Integer'First) = 0
              and then Arithmetic.Clamp (128) = 128
              and then Arithmetic.Clamp (Long_Integer'Last) = 255,
              "quantization channel clamping is wrong");
      Assert (Arithmetic.Squared_Distance ((0, 0, 0), (255, 255, 255)) = 195_075
              and then Arithmetic.Squared_Distance ((7, 8, 9), (7, 8, 9)) = 0,
              "quantization color distance is wrong");
   end Color_Arithmetic_Is_Bounded;

   procedure Pixel_Access_Is_Checked
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      package Pixels renames Giflib.Internal.Quantization_Pixels;
      Data : aliased constant Giflib.Streams.Byte_Array := [12, 34, 56];
      Valid_View : constant Giflib.Images.Image_View :=
        (Format => Giflib.RGB_24, Width => 1, Height => 1, Stride => 3,
         Accessible_Bytes => 3, Data => Data'Access);
      Short_View : constant Giflib.Images.Image_View :=
        (Format => Giflib.RGB_24, Width => 1, Height => 1, Stride => 3,
         Accessible_Bytes => 2, Data => Data'Access);
      Read : Pixels.Pixel_Result;
   begin
      Read := Pixels.Read_Pixel (Valid_View, 0, 0);
      Assert
        (Read.Valid and then Read.Value.Color = (12, 34, 56),
         "valid pixel access returned the wrong color");
      Read := Pixels.Read_Pixel (Valid_View, 1, 0);
      Assert (not Read.Valid, "out-of-range pixel access was accepted");
      Read := Pixels.Read_Pixel (Short_View, 0, 0);
      Assert (not Read.Valid, "short pixel storage was accessed");
   end Pixel_Access_Is_Checked;

   procedure Validates_Image_Views (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Data : aliased constant Giflib.Streams.Byte_Array := [for I in 1 .. 14 => Giflib.Byte (I)];
      View : Giflib.Images.Image_View :=
        (Format => Giflib.RGB_24, Width => 2, Height => 2, Stride => 8,
         Accessible_Bytes => 14, Data => Data'Access);
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
      View.Width := 1;
      View.Height := 2;
      View.Stride := Giflib.Row_Stride'Last;
      Outcome := Giflib.Images.Required_Bytes (View, Required);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Integer_Overflow
              and then Required = 0,
              "image extent overflow was accepted");
   end Validates_Image_Views;

   procedure Preserves_Exact_Colors (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Data : aliased constant Giflib.Streams.Byte_Array :=
        [255, 0, 0, 0, 255, 0, 0, 0, 255];
      View : constant Giflib.Images.Image_View :=
        (Format => Giflib.RGB_24, Width => 3, Height => 1, Stride => 9,
         Accessible_Bytes => 9, Data => Data'Access);
      Indexed : Giflib.Streams.Byte_Array (1 .. 3);
      Quantized : Giflib.Quantization.Quantization_Result;
      Outcome : Giflib.Results.Result;
   begin
      Outcome := Giflib.Quantization.Quantize
        (View, Indexed, Quantized);
      Assert (Giflib.Results.Succeeded (Outcome), "exact quantization failed");
      Assert (not Quantized.Transparency.Present and then Indexed = [0, 1, 2],
              "exact quantization changed color indices");
      Assert
        (Quantized.Palette.Length = 3
         and then Quantized.Palette.Colors (0) = (255, 0, 0)
         and then Quantized.Palette.Colors (1) = (0, 255, 0)
         and then Quantized.Palette.Colors (2) = (0, 0, 255),
         "exact palette did not preserve first-seen colors");

      declare
         One_Pixel : aliased constant Giflib.Streams.Byte_Array := [0, 0, 0];
         One_Pixel_View : constant Giflib.Images.Image_View :=
           (Format => Giflib.RGB_24,
            Width => 1,
            Height => 1,
            Stride => 3,
            Accessible_Bytes => 3,
            Data => One_Pixel'Access);
         Maximum_Bound_Output : Giflib.Streams.Byte_Array
           (Positive'Last .. Positive'Last);
      begin
         Outcome := Giflib.Quantization.Quantize
           (One_Pixel_View,
            Maximum_Bound_Output,
            Quantized);
         Assert
           (Giflib.Results.Succeeded (Outcome)
            and then Maximum_Bound_Output (Positive'Last) = 0,
            "quantization rejected a valid maximum-bound output array");
      end;
   end Preserves_Exact_Colors;

   procedure Quantizes_Many_Colors_Deterministically (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Data : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 17 * 17 * 3 => 0];
      View : constant Giflib.Images.Image_View :=
        (Data => Data'Access,
         Format => Giflib.RGB_24, Width => 17, Height => 17, Stride => 51,
         Accessible_Bytes => Data'Length);
      First, Second : Giflib.Streams.Byte_Array (1 .. 17 * 17);
      First_Result, Second_Result : Giflib.Quantization.Quantization_Result;
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
      Options.Palette.Maximum_Colors := 16;
      Outcome := Giflib.Quantization.Quantize
        (View, First, First_Result, Options);
      Assert (Giflib.Results.Succeeded (Outcome), "median-cut quantization failed");
      Outcome := Giflib.Quantization.Quantize
        (View, Second, Second_Result, Options);
      Assert (Giflib.Results.Succeeded (Outcome), "repeat median-cut quantization failed");
      Assert (First = Second and then First_Result.Palette = Second_Result.Palette,
              "median-cut output was not deterministic");
      Assert (First_Result.Palette.Length = 16
              and then not First_Result.Transparency.Present,
              "median-cut palette size was wrong");
      Position := Data'First;
      for I in First'Range loop
         Pixel := Natural (First (I));
         Chosen := First_Result.Palette.Colors (Giflib.Palette_Index (Pixel));
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
         Accessible_Bytes => 8, Data => RGBA'Access);
      Gradient : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 16 * 3 => 0];
      Gradient_View : constant Giflib.Images.Image_View :=
        (Data => Gradient'Access,
         Format => Giflib.RGB_24, Width => 16, Height => 1, Stride => 48,
         Accessible_Bytes => 48);
      Indexed : Giflib.Streams.Byte_Array (1 .. 2);
      Dithered, Repeated : Giflib.Streams.Byte_Array (1 .. 16);
      Quantized, Repeated_Result : Giflib.Quantization.Quantization_Result;
      Options : Giflib.Quantization.Quantize_Options := Giflib.Quantization.Default_Options;
      Outcome : Giflib.Results.Result;
   begin
      Options.Palette :=
        (Strategy => Giflib.Quantization.Use_Fixed_Palette,
         Fixed_Palette =>
           (Length => 3,
            Colors =>
              [0 => (255, 0, 0),
               1 => (0, 255, 0),
               2 => (0, 0, 0),
               others => <>]),
         Fixed_Transparent_Index => 2);
      Outcome := Giflib.Quantization.Quantize
        (RGBA_View, Indexed, Quantized, Options);
      Assert (Giflib.Results.Succeeded (Outcome)
              and then Quantized.Transparency.Present
              and then Quantized.Transparency.Index = 2
              and then Indexed = [2, 1],
              "alpha threshold or fixed transparent palette mapping failed");
      Options.Transparency := (Enabled => False);
      Outcome := Giflib.Quantization.Quantize
        (RGBA_View, Indexed, Quantized, Options);
      Assert
        (Giflib.Results.Succeeded (Outcome)
         and then not Quantized.Transparency.Present
         and then Indexed = [0, 1],
         "disabled transparency policy retained an alpha threshold or index");

      for I in 0 .. 15 loop
         Gradient (I * 3 + 1) := Giflib.Byte (I * 17);
         Gradient (I * 3 + 2) := Giflib.Byte (I * 17);
         Gradient (I * 3 + 3) := Giflib.Byte (I * 17);
      end loop;
      Options := Giflib.Quantization.Default_Options;
      Options.Palette.Maximum_Colors := 2;
      Options.Dither := Giflib.Quantization.Floyd_Steinberg;
      Outcome := Giflib.Quantization.Quantize
        (Gradient_View, Dithered, Quantized, Options);
      Assert (Giflib.Results.Succeeded (Outcome), "Floyd-Steinberg quantization failed");
      Outcome := Giflib.Quantization.Quantize
        (Gradient_View, Repeated, Repeated_Result, Options);
      Assert (Giflib.Results.Succeeded (Outcome)
              and then Dithered = Repeated
              and then Quantized.Palette = Repeated_Result.Palette,
              "Floyd-Steinberg output was not deterministic");
   end Handles_Alpha_Fixed_Palettes_And_Dither;

   procedure Handles_BGR_Channel_Orders
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      BGR : aliased constant Giflib.Streams.Byte_Array :=
        [0, 0, 255, 0, 255, 0];
      BGRA : aliased constant Giflib.Streams.Byte_Array :=
        [0, 0, 255, 0, 0, 255, 0, 255];
      BGR_View : constant Giflib.Images.Image_View :=
        (Format => Giflib.BGR_24, Width => 2, Height => 1, Stride => 6,
         Accessible_Bytes => 6, Data => BGR'Access);
      BGRA_View : constant Giflib.Images.Image_View :=
        (Format => Giflib.BGRA_32, Width => 2, Height => 1, Stride => 8,
         Accessible_Bytes => 8, Data => BGRA'Access);
      Indexed : Giflib.Streams.Byte_Array (1 .. 2);
      Quantized : Giflib.Quantization.Quantization_Result;
      Outcome : Giflib.Results.Result;
   begin
      Outcome := Giflib.Quantization.Quantize
        (BGR_View, Indexed, Quantized);
      Assert (Giflib.Results.Succeeded (Outcome)
              and then not Quantized.Transparency.Present
              and then Indexed = [0, 1]
              and then Quantized.Palette.Colors (0) = (255, 0, 0)
              and then Quantized.Palette.Colors (1) = (0, 255, 0),
              "BGR channel order changed during quantization");

      Outcome := Giflib.Quantization.Quantize
        (BGRA_View, Indexed, Quantized);
      Assert (Giflib.Results.Succeeded (Outcome)
              and then Quantized.Transparency.Present
              and then Quantized.Transparency.Index = 0
              and then Indexed = [0, 1]
              and then Quantized.Palette.Colors (1) = (0, 255, 0),
              "BGRA channel order or alpha handling changed");
   end Handles_BGR_Channel_Orders;

   procedure Enforces_Quantization_Budgets (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Data : aliased constant Giflib.Streams.Byte_Array := [0, 0, 0];
      Two_Colors : aliased constant Giflib.Streams.Byte_Array := [0, 0, 0, 255, 255, 255];
      View : constant Giflib.Images.Image_View :=
        (Format => Giflib.RGB_24, Width => 1, Height => 1, Stride => 3,
         Accessible_Bytes => 3, Data => Data'Access);
      Indexed : Giflib.Streams.Byte_Array (1 .. 1);
      Quantized : Giflib.Quantization.Quantization_Result;
      Constraints : Giflib.Limits.Limit_Set := Giflib.Limits.Default_Limits;
      Outcome : Giflib.Results.Result;
   begin
      Constraints.Max_Quantization_Work := 0;
      Outcome := Giflib.Quantization.Quantize
        (View, Indexed, Quantized,
         Constraints => Constraints);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded
              and then Outcome.First_Error.Context.Limit = Giflib.Quantization_Work_Limit,
              "quantization work budget was not enforced");
      Constraints := Giflib.Limits.Default_Limits;
      Constraints.Max_Allocation_Bytes := 1;
      Outcome := Giflib.Quantization.Quantize
        (View, Indexed, Quantized,
         Constraints => Constraints);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded
              and then Outcome.First_Error.Context.Limit = Giflib.Allocation_Byte_Limit,
              "quantization allocation budget was not enforced");

      declare
         Two_Color_View : constant Giflib.Images.Image_View :=
           (Format => Giflib.RGB_24, Width => 2, Height => 1, Stride => 6,
            Accessible_Bytes => 6, Data => Two_Colors'Access);
         Two_Indices : Giflib.Streams.Byte_Array (1 .. 2);
      begin
         Constraints := Giflib.Limits.Default_Limits;
         Constraints.Max_Quantization_Work := 32_770;
         Outcome := Giflib.Quantization.Quantize
           (Two_Color_View, Two_Indices, Quantized,
            Constraints => Constraints);
         Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded
                 and then Outcome.First_Error.Context.Limit = Giflib.Quantization_Work_Limit
                 and then Outcome.First_Error.Context.Actual = 32_771,
                 "exact-color comparisons escaped the quantization work budget");
      end;

      declare
         Transparent_Data : aliased constant Giflib.Streams.Byte_Array :=
           [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
         Transparent_View : constant Giflib.Images.Image_View :=
           (Format => Giflib.RGBA_32,
            Width => 4,
            Height => 1,
            Stride => 16,
            Accessible_Bytes => 16,
            Data => Transparent_Data'Access);
         Transparent_Indices : Giflib.Streams.Byte_Array (1 .. 4);
         Fixed : Giflib.Quantization.Quantize_Options :=
           Giflib.Quantization.Default_Options;
      begin
         Fixed.Palette :=
           (Strategy => Giflib.Quantization.Use_Fixed_Palette,
            Fixed_Palette => (Length => 2, others => <>),
            Fixed_Transparent_Index => 0);
         Constraints := Giflib.Limits.Default_Limits;
         Constraints.Max_Quantization_Work := 4_097;
         Outcome := Giflib.Quantization.Quantize
           (Transparent_View,
            Transparent_Indices,
            Quantized,
            Fixed,
            Constraints);
         Assert
           (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded
            and then Outcome.First_Error.Context.Limit =
              Giflib.Quantization_Work_Limit
            and then Outcome.First_Error.Context.Actual = 4_098,
            "transparent fixed-palette mapping escaped the work budget");
      end;

      declare
         package Palette_Builder renames
           Giflib.Internal.Quantization_Palette;
         Histogram : Palette_Builder.Histogram_State;
         Median_Palette : Giflib.Palettes.Palette;
         Work : Giflib.Internal.Work_Budgets.Meter (8);
      begin
         Histogram.Occupied_Count := 2;
         Histogram.Occupied (1) := 0;
         Histogram.Occupied (2) := Palette_Builder.Histogram_Index'Last;
         Histogram.Counts (0) := 1;
         Histogram.Counts (Palette_Builder.Histogram_Index'Last) := 1;
         Outcome := Palette_Builder.Build_Median_Cut
           (Histogram,
            Generated_Start => 0,
            Opaque_Capacity => 2,
            Work => Work,
            Output_Palette => Median_Palette);
         Assert
           (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded
            and then Outcome.First_Error.Context.Limit =
              Giflib.Quantization_Work_Limit
            and then Outcome.First_Error.Context.Actual = 9,
            "median-cut partitioning escaped the work budget");
      end;
   end Enforces_Quantization_Budgets;
end Giflib.Testing.Test_Quantization;
