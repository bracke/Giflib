separate (Giflib.Quantization)
function Map_Pixels
  (Context : in out Workspace;
   Source : Images.Image_View;
   Indexed_Pixels : out Streams.Byte_Array;
   Output_Palette : Palettes.Palette;
   Has_Transparency : Boolean;
   Transparent_Index : Palette_Index;
   Generated_Start : Natural;
   Options : Quantize_Options;
   Constraints : Limits.Limit_Set;
   Tracker : in out Work_Tracker) return Results.Result
is
   Use_Dither : constant Boolean := Options.Dither = Floyd_Steinberg;
   Outcome : Results.Result;
   Pixel : Pixels.Source_Pixel;
   Index : Natural := 0;

   function Work_Failure return Results.Result is
   begin
      return Results.Failure
        (Giflib.Errors.Make
           (Giflib.Errors.Limit_Exceeded,
            Internal.Resource_Diagnostics.With_Work_Limit
              (Tracker, Quantization_Work_Limit)));
   end Work_Failure;

begin
   Outcome := Ensure_Nearest_Cache (Context, Constraints);
   if not Results.Succeeded (Outcome) then
      return Outcome;
   end if;
   if not Storage_Operations.Reset_Nearest_Cache
     (Context.Resources, Tracker)
   then
      return Work_Failure;
   end if;
   if Use_Dither then
      Outcome := Ensure_Error_Buffer
        (Context, Source.Width, Constraints);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      if not Storage_Operations.Reset_Errors
        (Context.Resources,
         Buffer_Arithmetic.Error_Buffer_Length (Source.Width),
         Tracker)
      then
         return Work_Failure;
      end if;
   end if;

   for Y in 0 .. Natural (Source.Height) - 1 loop
      declare
         Span : constant Buffer_Arithmetic.Error_Span :=
           Buffer_Arithmetic.Span_Of (Source.Width);
         Current_Group : constant Buffer_Arithmetic.Group_Index :=
           (if Y mod 2 = 0 then 0 else 1);
         Next_Group : constant Buffer_Arithmetic.Group_Index :=
           (if Y mod 2 = 0 then 1 else 0);
      begin
         if Use_Dither then
            if not Charge
              (Tracker, Byte_Count (3) * Byte_Count (Span))
            then
               return Work_Failure;
            end if;
            Storage_Operations.Clear_Next_Row
              (Context.Resources, Next_Group, Span);
         end if;
         for X in 0 .. Natural (Source.Width) - 1 loop
            if not Charge (Tracker)
            then
               return Work_Failure;
            end if;
            Pixel := Pixels.Pixel_At (Source, X, Y);
            if Pixels.Is_Transparent
              (Pixel,
               Source.Format,
               Options.Transparency.Enabled,
               (if Options.Transparency.Enabled
                then Options.Transparency.Alpha_Threshold else 0))
            then
               Indexed_Pixels (Indexed_Pixels'First + Index) :=
                 Byte (Transparent_Index);
               if Use_Dither then
                  Storage_Operations.Clear_Transparent
                    (Context.Resources, Current_Group, X, Span);
               end if;
            else
               declare
                  Adjusted : Palettes.RGB_Color := Pixel.Color;
                  Chosen : Palette_Index;
               begin
                  if Use_Dither then
                     Adjusted := Storage_Operations.Adjust
                       (Context.Resources, Pixel.Color,
                        Current_Group, X, Span);
                  end if;
                  Chosen := Storage_Operations.Nearest
                    (Context.Resources,
                     Adjusted,
                     Output_Palette,
                     Generated_Start,
                     Has_Transparency
                       and then Options.Palette.Strategy = Use_Fixed_Palette,
                     Transparent_Index,
                     Tracker);
                  if Internal.Work_Budgets.Failed (Tracker) then
                     return Work_Failure;
                  end if;
                  Indexed_Pixels (Indexed_Pixels'First + Index) :=
                    Byte (Chosen);
                  if Use_Dither then
                     Storage_Operations.Diffuse
                       (Context.Resources,
                        Current_Group,
                        Next_Group,
                        X,
                        Span,
                        Adjusted,
                        Output_Palette.Colors (Chosen));
                  end if;
               end;
            end if;
            Index := Index + 1;
         end loop;
      end;
   end loop;
   return Results.Success;
end Map_Pixels;

