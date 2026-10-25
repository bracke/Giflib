with Giflib.Errors;
with Giflib.Internal.Quantization_Arithmetic;
with Giflib.Internal.Quantization_Pixels;
with Giflib.Internal.Quantization_Storage.Histogram_Operations;
with Giflib.Internal.Quantization_Storage.Outcomes;
with Giflib.Quantization.Workspace_Operations;

package body Giflib.Quantization.Palette_Building is
   package Arithmetic renames Internal.Quantization_Arithmetic;
   package Histogram renames
     Internal.Quantization_Storage.Histogram_Operations;
   package Outcomes renames Internal.Quantization_Storage.Outcomes;
   package Pixels renames Internal.Quantization_Pixels;
   package Workspace_Service renames Workspace_Operations;
   use type Outcomes.Budgeted_Status;
   use type Outcomes.Storage_Status;
   use type Palettes.RGB_Color;

   function Charge
     (Work : in out Internal.Work_Budgets.Meter) return Boolean
   is
      Accepted : Boolean;
   begin
      Internal.Work_Budgets.Try_Charge (Work, 1, Accepted);
      return Accepted;
   end Charge;

   type Exact_Color_Set is record
      Values : Palettes.Color_Array := [others => (others => 0)];
      Count : Natural := 0;
      Overflowed : Boolean := False;
   end record;

   function Prepare_Fixed
     (Source : Images.Image_View;
      Options : Quantize_Options;
      Work : in out Internal.Work_Budgets.Meter;
      Prepared : in out Prepared_Palette) return Results.Result
   is
      Pixel : Pixels.Pixel_Result;
   begin
      if Options.Transparency.Enabled
        and then Source.Format in RGBA_32 | BGRA_32
      then
         for Y in 0 .. Natural (Source.Height) - 1 loop
            exit when Prepared.Has_Transparency;
            for X in 0 .. Natural (Source.Width) - 1 loop
               if not Charge (Work) then
                  return Workspace_Service.Work_Failure (Work);
               end if;
               Pixel := Pixels.Read_Pixel (Source, X, Y);
               if not Pixel.Valid then
                  return Workspace_Service.Invariant_Failure;
               elsif Pixels.Is_Transparent
                 (Pixel.Value, Source.Format, True,
                  Options.Transparency.Alpha_Threshold)
               then
                  Prepared.Has_Transparency := True;
                  exit;
               end if;
            end loop;
         end loop;
      end if;
      if Prepared.Has_Transparency
        and then not Palettes.Contains
          (Options.Palette.Fixed_Palette,
           Options.Palette.Fixed_Transparent_Index)
      then
         return Results.Failure
           (Errors.Make (Errors.Palette_Index_Out_Of_Range));
      end if;
      Prepared.Value := Options.Palette.Fixed_Palette;
      Prepared.Transparent_Index := Options.Palette.Fixed_Transparent_Index;
      return Results.Success;
   end Prepare_Fixed;

   function Collect_Generated_Colors
     (Context : in out Workspace;
      Source : Images.Image_View;
      Options : Quantize_Options;
      Work : in out Internal.Work_Budgets.Meter;
      Prepared : in out Prepared_Palette;
      Exact : in out Exact_Color_Set) return Results.Result
   is
      Pixel : Pixels.Pixel_Result;
      Found : Boolean;
      Status : Outcomes.Storage_Status;
   begin
      for Y in 0 .. Natural (Source.Height) - 1 loop
         for X in 0 .. Natural (Source.Width) - 1 loop
            if not Charge (Work) then
               return Workspace_Service.Work_Failure (Work);
            end if;
            Pixel := Pixels.Read_Pixel (Source, X, Y);
            if not Pixel.Valid then
               return Workspace_Service.Invariant_Failure;
            elsif Pixels.Is_Transparent
              (Pixel.Value,
               Source.Format,
               Options.Transparency.Enabled,
               (if Options.Transparency.Enabled
                then Options.Transparency.Alpha_Threshold else 0))
            then
               Prepared.Has_Transparency := True;
            else
               Status := Histogram.Add_Sample
                 (Context.Resources,
                  Arithmetic.Histogram_Of (Pixel.Value.Color));
               if Status /= Outcomes.Storage_Ready then
                  return Workspace_Service.Invariant_Failure;
               end if;
               if not Exact.Overflowed then
                  Found := False;
                  for I in 0 .. Exact.Count - 1 loop
                     if not Charge (Work) then
                        return Workspace_Service.Work_Failure (Work);
                     elsif Exact.Values (Palette_Index (I)) = Pixel.Value.Color
                     then
                        Found := True;
                        exit;
                     end if;
                  end loop;
                  if not Found and then Exact.Count < 256 then
                     Exact.Values (Palette_Index (Exact.Count)) :=
                       Pixel.Value.Color;
                     Exact.Count := Exact.Count + 1;
                  elsif not Found then
                     Exact.Overflowed := True;
                  end if;
               end if;
            end if;
         end loop;
      end loop;
      return Results.Success;
   end Collect_Generated_Colors;

   function Finish_Generated_Palette
     (Context : in out Workspace;
      Options : Quantize_Options;
      Work : in out Internal.Work_Budgets.Meter;
      Exact : Exact_Color_Set;
      Prepared : in out Prepared_Palette) return Results.Result
   is
      Opaque_Capacity : Natural;
      Outcome : Results.Result;
   begin
      Prepared.Generated_Start :=
        (if Prepared.Has_Transparency then 1 else 0);
      if Prepared.Has_Transparency then
         Prepared.Transparent_Index := 0;
         Prepared.Value.Colors (0) := (others => 0);
      end if;
      Opaque_Capacity :=
        Options.Palette.Maximum_Colors - Prepared.Generated_Start;
      if not Exact.Overflowed and then Exact.Count <= Opaque_Capacity then
         for I in 0 .. Exact.Count - 1 loop
            Prepared.Value.Colors
              (Palette_Index (Prepared.Generated_Start + I)) :=
                Exact.Values (Palette_Index (I));
         end loop;
         Prepared.Value.Length := Prepared.Generated_Start + Exact.Count;
      else
         Outcome := Histogram.Build_Median_Cut
           (Context.Resources,
            Prepared.Generated_Start,
            Opaque_Capacity,
            Work,
            Prepared.Value);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;
      if Prepared.Value.Length < 2 then
         Prepared.Value.Length := 2;
         Prepared.Value.Colors (1) := Prepared.Value.Colors (0);
      end if;
      return Results.Success;
   end Finish_Generated_Palette;

   function Build
     (Context : in out Workspace;
      Source : Images.Image_View;
      Options : Quantize_Options;
      Constraints : Limits.Limit_Set;
      Work : in out Internal.Work_Budgets.Meter;
      Prepared : out Prepared_Palette) return Results.Result
   is
      Exact : Exact_Color_Set;
      Reset_Status : Outcomes.Budgeted_Status;
      Outcome : Results.Result;
   begin
      Prepared := (others => <>);
      if Options.Palette.Strategy = Use_Fixed_Palette then
         return Prepare_Fixed (Source, Options, Work, Prepared);
      end if;
      Outcome := Workspace_Service.Ensure_Histogram (Context, Constraints);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      Reset_Status := Histogram.Reset (Context.Resources, Work);
      if Reset_Status = Outcomes.Budgeted_Work_Limit then
         return Workspace_Service.Work_Failure (Work);
      elsif Reset_Status /= Outcomes.Budgeted_Ready then
         return Workspace_Service.Invariant_Failure;
      end if;
      Outcome := Collect_Generated_Colors
        (Context, Source, Options, Work, Prepared, Exact);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      return Finish_Generated_Palette
        (Context, Options, Work, Exact, Prepared);
   end Build;
end Giflib.Quantization.Palette_Building;
