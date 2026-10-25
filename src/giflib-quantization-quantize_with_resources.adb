separate (Giflib.Quantization)
function Quantize_With_Resources
  (Context : in out Workspace;
   Source : Images.Image_View;
   Indexed_Pixels : out Streams.Byte_Array;
   Output : out Quantization_Result;
   Options : Quantize_Options;
   Constraints : Limits.Limit_Set) return Results.Result
is
   Pixel_Total : constant Byte_Count :=
     Internal.Geometry_Arithmetic.Area (Source.Width, Source.Height);
   Exact_Colors : Palettes.Color_Array := [others => (others => 0)];
   Exact_Count : Natural := 0;
   Exact_Overflow : Boolean := False;
   Tracker : Work_Tracker (Constraints.Max_Quantization_Work);
   Generated_Start : Natural := 0;
   Opaque_Capacity : Natural;
   Output_Palette : Palettes.Palette := (others => <>);
   Has_Transparency : Boolean := False;
   Transparent_Index : Palette_Index := 0;

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
   if Options.Palette.Strategy = Use_Fixed_Palette then
      if Options.Transparency.Enabled
        and then Source.Format in RGBA_32 | BGRA_32
      then
         for Y in 0 .. Natural (Source.Height) - 1 loop
            exit when Has_Transparency;
            for X in 0 .. Natural (Source.Width) - 1 loop
               if not Charge (Tracker)
               then
                  return Fail
                    (Giflib.Errors.Limit_Exceeded,
                     Internal.Resource_Diagnostics.With_Work_Limit
                       (Tracker, Quantization_Work_Limit));
               end if;
               if Pixels.Is_Transparent
                 (Pixels.Pixel_At (Source, X, Y),
                  Source.Format,
                  Options.Transparency.Enabled,
                  (if Options.Transparency.Enabled
                   then Options.Transparency.Alpha_Threshold else 0))
               then
                  Has_Transparency := True;
                  exit;
               end if;
            end loop;
         end loop;
      end if;
      if Has_Transparency
        and then not Palettes.Contains
          (Options.Palette.Fixed_Palette,
           Options.Palette.Fixed_Transparent_Index)
      then
         return Fail (Giflib.Errors.Palette_Index_Out_Of_Range);
      end if;
      Output_Palette := Options.Palette.Fixed_Palette;
      Transparent_Index := Options.Palette.Fixed_Transparent_Index;
      Generated_Start := 0;
   else
      Outcome := Ensure_Histogram
        (Context, Constraints);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      if not Storage_Operations.Reset_Histogram
        (Context.Resources, Tracker)
      then
         return Fail
           (Giflib.Errors.Limit_Exceeded,
            Internal.Resource_Diagnostics.With_Work_Limit
              (Tracker, Quantization_Work_Limit));
      end if;
      for Y in 0 .. Natural (Source.Height) - 1 loop
         for X in 0 .. Natural (Source.Width) - 1 loop
            if not Charge (Tracker)
            then
               return Fail
                 (Giflib.Errors.Limit_Exceeded,
                  Internal.Resource_Diagnostics.With_Work_Limit
                    (Tracker, Quantization_Work_Limit));
            end if;
            Pixel := Pixels.Pixel_At (Source, X, Y);
            if Pixels.Is_Transparent
              (Pixel,
               Source.Format,
               Options.Transparency.Enabled,
               (if Options.Transparency.Enabled
                then Options.Transparency.Alpha_Threshold else 0))
            then
               Has_Transparency := True;
            else
               Bucket := Arithmetic.Histogram_Of (Pixel.Color);
               Storage_Operations.Add_Histogram_Sample
                 (Context.Resources, Bucket);
               if not Exact_Overflow then
                  Found := False;
                  for I in 0 .. Exact_Count - 1 loop
                     if not Charge (Tracker)
                     then
                        return Fail
                          (Giflib.Errors.Limit_Exceeded,
                           Internal.Resource_Diagnostics.With_Work_Limit
                             (Tracker, Quantization_Work_Limit));
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
      Opaque_Capacity := Options.Palette.Maximum_Colors - Generated_Start;
      if not Exact_Overflow and then Exact_Count <= Opaque_Capacity then
         for I in 0 .. Exact_Count - 1 loop
            Output_Palette.Colors (Palette_Index (Generated_Start + I)) :=
              Exact_Colors (Palette_Index (I));
         end loop;
         Output_Palette.Length := Generated_Start + Exact_Count;
      else
         Outcome := Storage_Operations.Build_Median_Cut
           (Context.Resources,
            Generated_Start,
            Opaque_Capacity,
            Tracker,
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

   if Has_Transparency
     and then Options.Palette.Strategy = Use_Fixed_Palette
   then
      Generated_Start := 0;
   elsif Has_Transparency then
      Generated_Start := 1;
   else
      Generated_Start := 0;
   end if;

   Outcome := Map_Pixels
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
   if not Results.Succeeded (Outcome) then
      return Outcome;
   end if;
   Output :=
     (Palette => Output_Palette,
      Transparency =>
        (if Has_Transparency
         then (Present => True, Index => Transparent_Index)
         else (Present => False)));
   return Results.Success;
end Quantize_With_Resources;

