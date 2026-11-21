with Giflib.Errors;
with Giflib.Internal.Quantization_Pixels;
with Giflib.Quantization.Workspace_Operations;

package body Giflib.Quantization.Palette_Building.Fixed_Strategy is
   package Pixels renames Internal.Quantization_Pixels;

   function Build
     (Source : Images.Image_View;
      Options : Quantize_Options;
      Work : in out Internal.Work_Budgets.Meter;
      Prepared : out Prepared_Palette) return Results.Result
   is
      Accepted : Boolean;
      Position : Positive;
      Remaining : Natural;
      Bytes_Per_Pixel : constant Positive := 4;
   begin
      Prepared := (others => <>);
      if Options.Transparency.Enabled and then Source.Format in RGBA_32 | BGRA_32
      then
         for Y in 0 .. Natural (Source.Height) - 1 loop
            exit when Prepared.Has_Transparency;
            Internal.Work_Budgets.Try_Charge
              (Work, Byte_Count (Source.Width), Accepted);
            if not Accepted then
               return Workspace_Operations.Work_Failure (Work);
            end if;
            Position := Pixels.Row_Start (Source, Y) + 3;
            Remaining := Natural (Source.Width);
            while Remaining > 0 loop
               if Source.Data (Position) <=
                 Options.Transparency.Alpha_Threshold
               then
                  Prepared.Has_Transparency := True;
                  exit;
               end if;
               Position := Position + Bytes_Per_Pixel;
               Remaining := Remaining - 1;
            end loop;
         end loop;
      end if;
      if Prepared.Has_Transparency and then not Palettes.Contains
        (Options.Palette.Fixed_Palette,
         Options.Palette.Fixed_Transparent_Index)
      then
         return Results.Failure
           (Errors.Make (Errors.Palette_Index_Out_Of_Range));
      end if;
      Prepared.Value := Options.Palette.Fixed_Palette;
      Prepared.Transparent_Index := Options.Palette.Fixed_Transparent_Index;
      return Results.Success;
   end Build;
end Giflib.Quantization.Palette_Building.Fixed_Strategy;
