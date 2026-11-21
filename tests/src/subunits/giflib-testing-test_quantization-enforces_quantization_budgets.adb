separate (Giflib.Testing.Test_Quantization)
procedure Enforces_Quantization_Budgets (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Data : aliased constant Giflib.Streams.Byte_Array := [0, 0, 0];
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
   declare
      Fixed : Giflib.Quantization.Quantize_Options :=
        Giflib.Quantization.Default_Options;
   begin
      Fixed.Palette :=
        (Strategy => Giflib.Quantization.Use_Fixed_Palette,
         Fixed_Palette => (Length => 2, others => <>),
         Fixed_Transparent_Index => 0);
      Outcome := Giflib.Quantization.Quantize
        (View, Indexed, Quantized, Fixed, Constraints);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded
              and then Outcome.First_Error.Context.Limit =
                Giflib.Allocation_Byte_Limit,
              "quantization allocation budget was not enforced");
   end;
   declare
      Two_Colors : aliased constant Giflib.Streams.Byte_Array :=
        [0, 0, 0, 255, 255, 255];
      Two_Color_View : constant Giflib.Images.Image_View :=
        (Format => Giflib.RGB_24, Width => 2, Height => 1, Stride => 6,
         Accessible_Bytes => 6, Data => Two_Colors'Access);
      Two_Indices : Giflib.Streams.Byte_Array (1 .. 2);
   begin
      Constraints := Giflib.Limits.Default_Limits;
      Constraints.Max_Quantization_Work := 3;
      Outcome := Giflib.Quantization.Quantize
        (Two_Color_View, Two_Indices, Quantized,
         Constraints => Constraints);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded
              and then Outcome.First_Error.Context.Limit = Giflib.Quantization_Work_Limit
              and then Outcome.First_Error.Context.Actual = 4,
              "exact-color hash probes escaped the quantization work budget");
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
      Constraints.Max_Quantization_Work := 5;
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
         and then Outcome.First_Error.Context.Actual = 6,
         "transparent fixed-palette mapping escaped the work budget");
   end;

   declare
      package Palette_Builder renames
        Giflib.Internal.Quantization_Palette;
      package Histograms renames
        Giflib.Internal.Quantization_Histograms;
      Histogram : Histograms.Histogram_State;
      Median_Palette : Giflib.Palettes.Palette;
      Work : Giflib.Internal.Work_Budgets.Meter (8);
   begin
      Histogram.Occupied_Count := 2;
      Histogram.Occupied (1) := 0;
      Histogram.Occupied (2) := Histograms.Histogram_Index'Last;
      Histogram.Counts (0) := 1;
      Histogram.Counts (Histograms.Histogram_Index'Last) := 1;
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
