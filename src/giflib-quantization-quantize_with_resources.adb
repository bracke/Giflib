separate (Giflib.Quantization)
function Quantize_With_Resources
  (Context : in out Workspace;
   Source : Images.Image_View;
   Indexed_Pixels : out Streams.Byte_Array;
   Output_Palette : out Palettes.Palette;
   Has_Transparency : out Boolean;
   Transparent_Index : out Palette_Index;
   Options : Quantize_Options;
   Constraints : Limits.Limit_Set) return Results.Result
is
   Pixel_Total : constant Byte_Count :=
     Internal.Geometry_Arithmetic.Area (Source.Width, Source.Height);
   Histogram : Histogram_State_Access renames Context.Resources.Histogram;
   Exact_Colors : Palettes.Color_Array := [others => (others => 0)];
   Exact_Count : Natural := 0;
   Exact_Overflow : Boolean := False;
   Tracker : Work_Tracker;
   Generated_Start : Natural := 0;
   Opaque_Capacity : Natural;

   function Fail
     (Code : Giflib.Errors.Error_Code;
      Context : Giflib.Errors.Diagnostic_Context := (others => <>)) return Results.Result
   is
   begin
      return Results.Failure (Giflib.Errors.Make (Code, Context));
   end Fail;

   Outcome : Results.Result;
   Pixel : Pixels.Source_Pixel;
   Found : Boolean;
   Bucket : Histogram_Index;
begin
   Output_Palette := (others => <>);
   Has_Transparency := False;
   Transparent_Index := 0;
   Outcome := Validate_Request
     (Context,
      Source,
      Indexed_Pixels'Length,
      Options,
      Constraints,
      Pixel_Total);
   if not Results.Succeeded (Outcome) then
      return Outcome;
   end if;
   if Options.Strategy = Use_Fixed_Palette then
      if Options.Use_Transparency
        and then Source.Format in RGBA_32 | BGRA_32
      then
         for Y in 0 .. Natural (Source.Height) - 1 loop
            exit when Has_Transparency;
            for X in 0 .. Natural (Source.Width) - 1 loop
               if not Charge
                 (Tracker, Constraints.Max_Quantization_Work)
               then
                  return Fail
                    (Giflib.Errors.Limit_Exceeded,
                     (Expected => Constraints.Max_Quantization_Work,
                      Actual => Tracker.Attempted,
                      Limit => Quantization_Work_Limit, others => <>));
               end if;
               if Pixels.Is_Transparent
                 (Pixels.Pixel_At (Source, X, Y),
                  Source.Format,
                  Options.Use_Transparency,
                  Options.Alpha_Threshold)
               then
                  Has_Transparency := True;
                  exit;
               end if;
            end loop;
         end loop;
      end if;
      if Has_Transparency
        and then not Palettes.Contains
          (Options.Fixed_Palette, Options.Fixed_Transparent_Index)
      then
         return Fail (Giflib.Errors.Palette_Index_Out_Of_Range);
      end if;
      Output_Palette := Options.Fixed_Palette;
      Transparent_Index := Options.Fixed_Transparent_Index;
      Generated_Start := 0;
   else
      Outcome := Ensure_Histogram
        (Context, Constraints);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      if not Charge
        (Tracker,
         Constraints.Max_Quantization_Work,
         Byte_Count (Histogram.Counts'Length))
      then
         return Fail
           (Giflib.Errors.Limit_Exceeded,
            (Expected => Constraints.Max_Quantization_Work,
             Actual => Tracker.Attempted,
             Limit => Quantization_Work_Limit,
             others => <>));
      end if;
      Histogram.Counts := [others => 0];
      Histogram.Occupied_Count := 0;

      for Y in 0 .. Natural (Source.Height) - 1 loop
         for X in 0 .. Natural (Source.Width) - 1 loop
            if not Charge
              (Tracker, Constraints.Max_Quantization_Work)
            then
               return Fail
                 (Giflib.Errors.Limit_Exceeded,
                  (Expected => Constraints.Max_Quantization_Work,
                   Actual => Tracker.Attempted,
                   Limit => Quantization_Work_Limit, others => <>));
            end if;
            Pixel := Pixels.Pixel_At (Source, X, Y);
            if Pixels.Is_Transparent
              (Pixel,
               Source.Format,
               Options.Use_Transparency,
               Options.Alpha_Threshold)
            then
               Has_Transparency := True;
            else
               Bucket := Arithmetic.Histogram_Of (Pixel.Color);
               if Histogram.Counts (Bucket) = 0 then
                  Histogram.Occupied_Count := Histogram.Occupied_Count + 1;
                  Histogram.Occupied (Histogram.Occupied_Count) := Bucket;
               end if;
               Histogram.Counts (Bucket) := Histogram.Counts (Bucket) + 1;
               if not Exact_Overflow then
                  Found := False;
                  for I in 0 .. Exact_Count - 1 loop
                     if not Charge
                       (Tracker, Constraints.Max_Quantization_Work)
                     then
                        return Fail
                          (Giflib.Errors.Limit_Exceeded,
                           (Expected => Constraints.Max_Quantization_Work,
                            Actual => Tracker.Attempted,
                            Limit => Quantization_Work_Limit,
                            others => <>));
                     end if;
                     if Exact_Colors (Palette_Index (I)) = Pixel.Color then
                        Found := True;
                        exit;
                     end if;
                  end loop;
                  if not Found and then Exact_Count < 256 then
                     Exact_Colors (Palette_Index (Exact_Count)) := Pixel.Color;
                     Exact_Count := Exact_Count + 1;
                  elsif not Found then
                     Exact_Overflow := True;
                  end if;
               end if;
            end if;
         end loop;
      end loop;
      if Has_Transparency then
         Transparent_Index := 0;
         Generated_Start := 1;
         Output_Palette.Colors (0) := (others => 0);
      else
         Generated_Start := 0;
      end if;
      Opaque_Capacity := Options.Maximum_Colors - Generated_Start;
      if not Exact_Overflow and then Exact_Count <= Opaque_Capacity then
         for I in 0 .. Exact_Count - 1 loop
            Output_Palette.Colors (Palette_Index (Generated_Start + I)) :=
              Exact_Colors (Palette_Index (I));
         end loop;
         Output_Palette.Length := Generated_Start + Exact_Count;
      else
         Outcome := Palette_Builder.Build_Median_Cut
           (Histogram.all,
            Generated_Start,
            Opaque_Capacity,
            Tracker.Total,
            Constraints.Max_Quantization_Work,
            Output_Palette);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;
      if Output_Palette.Length < 2 then
         Output_Palette.Length := 2;
         Output_Palette.Colors (Palette_Index (1)) := Output_Palette.Colors (Palette_Index (0));
      end if;
   end if;

   if Has_Transparency and then Options.Strategy = Use_Fixed_Palette then
      Generated_Start := 0;
   elsif Has_Transparency then
      Generated_Start := 1;
   else
      Generated_Start := 0;
   end if;

   return Map_Pixels
     (Context,
      Source,
      Indexed_Pixels,
      Output_Palette,
      Has_Transparency,
      Transparent_Index,
      Generated_Start,
      Options,
      Constraints,
      Tracker);
end Quantize_With_Resources;

