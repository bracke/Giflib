separate (Giflib.Testing.Test_Quantization)
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

   declare
      Width : constant := 17;
      Height : constant := 17;
      Data : aliased Giflib.Streams.Byte_Array :=
        [for I in 1 .. Width * Height * 3 => 0];
      View : constant Giflib.Images.Image_View :=
        (Data => Data'Access, Format => Giflib.RGB_24,
         Width => Width, Height => Height, Stride => Width * 3,
         Accessible_Bytes => Data'Length);
      Mapped : Giflib.Streams.Byte_Array (1 .. Width * Height);
      Fixed : Giflib.Palettes.Palette;
      Best : Natural;
      Best_Distance : Natural;
      Distance : Natural;
      Position : Natural;
      Color : Giflib.Palettes.RGB_Color;
   begin
      Fixed.Length := 256;
      for I in Giflib.Palette_Index loop
         Fixed.Colors (I) :=
           (Giflib.Byte (I), Giflib.Byte (Natural (I) * 37 mod 256),
            Giflib.Byte (Natural (I) * 73 mod 256));
      end loop;
      for Y in 0 .. Height - 1 loop
         for X in 0 .. Width - 1 loop
            Position := (Y * Width + X) * 3 + 1;
            Data (Position) := Giflib.Byte (X * 15);
            Data (Position + 1) := Giflib.Byte (Y * 15);
            Data (Position + 2) := Giflib.Byte ((X * 19 + Y * 23) mod 256);
         end loop;
      end loop;
      Options := Giflib.Quantization.Default_Options;
      Options.Transparency := (Enabled => False);
      Options.Palette :=
        (Strategy => Giflib.Quantization.Use_Fixed_Palette,
         Fixed_Palette => Fixed, Fixed_Transparent_Index => 0);
      Outcome := Giflib.Quantization.Quantize
        (View, Mapped, Quantized, Options);
      Assert
        (Giflib.Results.Succeeded (Outcome),
         "fixed-palette nearest-color search failed");
      for Pixel in Mapped'Range loop
         Position := (Pixel - Mapped'First) * 3 + 1;
         Color := (Data (Position), Data (Position + 1), Data (Position + 2));
         Best := 0;
         Best_Distance := Natural'Last;
         for I in 0 .. Fixed.Length - 1 loop
            Distance := Natural
              (Giflib.Internal.Quantization_Arithmetic.Squared_Distance
                 (Color, Fixed.Colors (Giflib.Palette_Index (I))));
            if Distance < Best_Distance then
               Best := I;
               Best_Distance := Distance;
            end if;
         end loop;
         Assert
           (Mapped (Pixel) = Giflib.Byte (Best),
            "nearest-color search differs from exhaustive mapping");
      end loop;
   end;

   declare
      Duplicate_Palette : constant Giflib.Palettes.Palette :=
        (Length => 256, Colors => [others => (17, 29, 43)]);
      Search : Giflib.Internal.Quantization_Mapping.Search_Index;
      Work : Giflib.Internal.Work_Budgets.Meter (100_000);
   begin
      Outcome := Giflib.Internal.Quantization_Mapping.Build
        (Duplicate_Palette, First => 0, Exclude_Index => False,
         Excluded_Index => 0, Work => Work, Object => Search);
      Assert
        (Giflib.Results.Succeeded (Outcome)
         and then Giflib.Internal.Quantization_Mapping.Node_Count (Search) = 1
         and then Giflib.Internal.Work_Budgets.Used (Work) < 5_000,
         "duplicate fixed-palette colors were not canonicalized in bounded sorted work");
   end;

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

