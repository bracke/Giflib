with Giflib.Internal.Quantization_Buffer_Arithmetic;
with Giflib.Internal.Quantization_Mapping;
with Giflib.Internal.Quantization_Pixels;
with Giflib.Internal.Quantization_Storage.Cache_Operations;
with Giflib.Internal.Quantization_Storage.Dither_Operations;
with Giflib.Internal.Quantization_Storage.Outcomes;
with Giflib.Quantization.Workspace_Operations;

package body Giflib.Quantization.Pixel_Mapping is
   package Buffer_Arithmetic renames
     Internal.Quantization_Buffer_Arithmetic;
   package Cache renames
     Internal.Quantization_Storage.Cache_Operations;
   package Dither renames
     Internal.Quantization_Storage.Dither_Operations;
   package Mapping renames Internal.Quantization_Mapping;
   package Outcomes renames Internal.Quantization_Storage.Outcomes;
   package Pixels renames Internal.Quantization_Pixels;
   package Workspace_Service renames Workspace_Operations;
   use type Outcomes.Budgeted_Status;
   use type Outcomes.Storage_Status;

   function Map
     (Context : in out Workspace;
      Source : Images.Image_View;
      Indexed_Pixels : out Streams.Byte_Array;
      Prepared : Palette_Building.Prepared_Palette;
      Options : Quantize_Options;
      Constraints : Limits.Limit_Set;
      Work : in out Internal.Work_Budgets.Meter) return Results.Result
   is
      Use_Dither : constant Boolean := Options.Dither = Floyd_Steinberg;
      Outcome : Results.Result;
      Pixel : Pixels.Pixel_Result;
      Index : Natural := 0;
      Budgeted : Outcomes.Budgeted_Status;
      Status : Outcomes.Storage_Status;
      Accepted : Boolean;
   begin
      Outcome := Workspace_Service.Ensure_Nearest_Cache
        (Context, Constraints);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      Budgeted := Cache.Reset (Context.Resources, Work);
      if Budgeted = Outcomes.Budgeted_Work_Limit then
         return Workspace_Service.Work_Failure (Work);
      elsif Budgeted /= Outcomes.Budgeted_Ready then
         return Workspace_Service.Invariant_Failure;
      end if;
      if Use_Dither then
         Outcome := Workspace_Service.Ensure_Error_Buffer
           (Context, Source.Width, Constraints);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
         Budgeted := Dither.Reset
           (Context.Resources,
            Buffer_Arithmetic.Error_Buffer_Length (Source.Width),
            Work);
         if Budgeted = Outcomes.Budgeted_Work_Limit then
            return Workspace_Service.Work_Failure (Work);
         elsif Budgeted /= Outcomes.Budgeted_Ready then
            return Workspace_Service.Invariant_Failure;
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
               Internal.Work_Budgets.Try_Charge
                 (Work, Byte_Count (3) * Byte_Count (Span), Accepted);
               if not Accepted then
                  return Workspace_Service.Work_Failure (Work);
               end if;
               Status := Dither.Clear_Next_Row
                 (Context.Resources, Next_Group, Span);
               if Status /= Outcomes.Storage_Ready then
                  return Workspace_Service.Invariant_Failure;
               end if;
            end if;
            for X in 0 .. Natural (Source.Width) - 1 loop
               Internal.Work_Budgets.Try_Charge (Work, 1, Accepted);
               if not Accepted then
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
                  Indexed_Pixels (Indexed_Pixels'First + Index) :=
                    Byte (Prepared.Transparent_Index);
                  if Use_Dither then
                     Status := Dither.Clear_Transparent
                       (Context.Resources, Current_Group, X, Span);
                     if Status /= Outcomes.Storage_Ready then
                        return Workspace_Service.Invariant_Failure;
                     end if;
                  end if;
               else
                  declare
                     Adjusted : Palettes.RGB_Color := Pixel.Value.Color;
                     Chosen : Palette_Index;
                     Adjusted_Result : Dither.Color_Outcome;
                  begin
                     if Use_Dither then
                        Adjusted_Result := Dither.Adjust
                          (Context.Resources, Pixel.Value.Color,
                           Current_Group, X, Span);
                        if Adjusted_Result.Status /= Outcomes.Storage_Ready then
                           return Workspace_Service.Invariant_Failure;
                        end if;
                        Adjusted := Adjusted_Result.Value;
                     end if;
                     Outcome := Mapping.Find
                       (Context.Resources,
                        Adjusted,
                        Prepared.Value,
                        Prepared.Generated_Start,
                        Prepared.Has_Transparency
                          and then Options.Palette.Strategy = Use_Fixed_Palette,
                        Prepared.Transparent_Index,
                        Work,
                        Chosen);
                     if not Results.Succeeded (Outcome) then
                        return Outcome;
                     end if;
                     Indexed_Pixels (Indexed_Pixels'First + Index) :=
                       Byte (Chosen);
                     if Use_Dither then
                        Status := Dither.Diffuse
                          (Context.Resources,
                           Current_Group,
                           Next_Group,
                           X,
                           Span,
                           Adjusted,
                           Prepared.Value.Colors (Chosen));
                        if Status /= Outcomes.Storage_Ready then
                           return Workspace_Service.Invariant_Failure;
                        end if;
                     end if;
                  end;
               end if;
               Index := Index + 1;
            end loop;
         end;
      end loop;
      return Results.Success;
   end Map;
end Giflib.Quantization.Pixel_Mapping;
