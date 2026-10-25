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
   use type Storage_Operations.Operation_Status;
   Use_Dither : constant Boolean := Options.Dither = Floyd_Steinberg;
   Outcome : Results.Result;
   Pixel : Pixels.Source_Pixel;
   Pixel_Read : Pixels.Pixel_Result;
   Index : Natural := 0;

   function Work_Failure return Results.Result is
   begin
      return Results.Failure
        (Giflib.Errors.Make
           (Giflib.Errors.Limit_Exceeded,
            Internal.Resource_Diagnostics.With_Work_Limit
              (Tracker, Quantization_Work_Limit)));
   end Work_Failure;

   function Invariant_Failure return Results.Result is
     (Results.Failure
        (Giflib.Errors.Make (Giflib.Errors.Internal_Invariant_Failed)));

   function Status_Failure
     (Status : Storage_Operations.Operation_Status) return Results.Result is
     (if Status = Storage_Operations.Operation_Work_Limit
          and then Internal.Work_Budgets.Failed (Tracker)
      then Work_Failure
      else Invariant_Failure);

   Status : Storage_Operations.Operation_Status;

begin
   Outcome := Ensure_Nearest_Cache (Context, Constraints);
   if not Results.Succeeded (Outcome) then
      return Outcome;
   end if;
   Status := Cache_Operations.Reset
     (Context.Resources, Tracker);
   if Status /= Storage_Operations.Operation_Ready then
      return Status_Failure (Status);
   end if;
   if Use_Dither then
      Outcome := Ensure_Error_Buffer
        (Context, Source.Width, Constraints);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      Status := Dither_Operations.Reset
        (Context.Resources,
         Buffer_Arithmetic.Error_Buffer_Length (Source.Width),
         Tracker);
      if Status /= Storage_Operations.Operation_Ready then
         return Status_Failure (Status);
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
            Status := Dither_Operations.Clear_Next_Row
              (Context.Resources, Next_Group, Span);
            if Status /= Storage_Operations.Operation_Ready then
               return Status_Failure (Status);
            end if;
         end if;
         for X in 0 .. Natural (Source.Width) - 1 loop
            if not Charge (Tracker)
            then
               return Work_Failure;
            end if;
            Pixel_Read := Pixels.Read_Pixel (Source, X, Y);
            if not Pixel_Read.Valid then
               return Invariant_Failure;
            end if;
            Pixel := Pixel_Read.Value;
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
                  Status := Dither_Operations.Clear_Transparent
                    (Context.Resources, Current_Group, X, Span);
                  if Status /= Storage_Operations.Operation_Ready then
                     return Status_Failure (Status);
                  end if;
               end if;
            else
               declare
                  Adjusted : Palettes.RGB_Color := Pixel.Color;
                  Chosen : Palette_Index;
                  Adjusted_Result : Storage_Operations.Color_Outcome;
               begin
                  if Use_Dither then
                     Adjusted_Result := Dither_Operations.Adjust
                       (Context.Resources, Pixel.Color,
                        Current_Group, X, Span);
                     if Adjusted_Result.Status /=
                       Storage_Operations.Operation_Ready
                     then
                        return Status_Failure (Adjusted_Result.Status);
                     end if;
                     Adjusted := Adjusted_Result.Value;
                  end if;
                  Outcome := Mapping.Find
                    (Context.Resources,
                     Adjusted,
                     Output_Palette,
                     Generated_Start,
                     Has_Transparency
                       and then Options.Palette.Strategy = Use_Fixed_Palette,
                     Transparent_Index,
                     Tracker,
                     Chosen);
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
                  Indexed_Pixels (Indexed_Pixels'First + Index) :=
                    Byte (Chosen);
                  if Use_Dither then
                     Status := Dither_Operations.Diffuse
                       (Context.Resources,
                        Current_Group,
                        Next_Group,
                        X,
                        Span,
                        Adjusted,
                        Output_Palette.Colors (Chosen));
                     if Status /= Storage_Operations.Operation_Ready then
                        return Status_Failure (Status);
                     end if;
                  end if;
               end;
            end if;
            Index := Index + 1;
         end loop;
      end;
   end loop;
   return Results.Success;
end Map_Pixels;

