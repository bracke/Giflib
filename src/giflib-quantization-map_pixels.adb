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
      then Work_Failure
      else Invariant_Failure);

   function Find_Nearest
     (Color : Palettes.RGB_Color;
      Chosen : out Palette_Index) return Results.Result
   is
      Key : constant Natural := Pixels.Color_Key (Color);
      Probe : constant Storage_Operations.Cache_Probe_Result :=
        Storage_Operations.Probe_Nearest_Cache
          (Context.Resources, Key,
           Pixels.Cache_Start
             (Key, Storage_Operations.Nearest_Cache_Capacity));
      Best : Natural := Generated_Start;
      Best_Distance : Natural := Natural'Last;
      Distance : Natural;
      Status : Storage_Operations.Operation_Status;
   begin
      Chosen := 0;
      if Probe.Status /= Storage_Operations.Operation_Ready then
         return Status_Failure (Probe.Status);
      elsif not Charge (Tracker, Byte_Count (Probe.Probe_Count)) then
         return Work_Failure;
      elsif Probe.Found then
         Chosen := Probe.Value;
         return Results.Success;
      elsif Output_Palette.Length <= Generated_Start then
         return Invariant_Failure;
      elsif not Charge
        (Tracker, Byte_Count (Output_Palette.Length - Generated_Start))
      then
         return Work_Failure;
      end if;
      for I in Generated_Start .. Output_Palette.Length - 1 loop
         if not (Has_Transparency
                 and then Options.Palette.Strategy = Use_Fixed_Palette
                 and then Palette_Index (I) = Transparent_Index)
         then
            Distance := Natural
              (Arithmetic.Squared_Distance
                 (Color, Output_Palette.Colors (Palette_Index (I))));
            if Distance < Best_Distance then
               Best := I;
               Best_Distance := Distance;
            end if;
         end if;
      end loop;
      if Best_Distance = Natural'Last then
         return Invariant_Failure;
      end if;
      Chosen := Palette_Index (Best);
      Status := Storage_Operations.Store_Nearest_Cache
        (Context.Resources, Probe.Store_Slot, Key, Chosen);
      return (if Status = Storage_Operations.Operation_Ready
              then Results.Success else Status_Failure (Status));
   end Find_Nearest;

   Status : Storage_Operations.Operation_Status;

begin
   Outcome := Ensure_Nearest_Cache (Context, Constraints);
   if not Results.Succeeded (Outcome) then
      return Outcome;
   end if;
   Status := Storage_Operations.Reset_Nearest_Cache
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
      Status := Storage_Operations.Reset_Errors
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
            Status := Storage_Operations.Clear_Next_Row
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
                  Status := Storage_Operations.Clear_Transparent
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
                     Adjusted_Result := Storage_Operations.Adjust
                       (Context.Resources, Pixel.Color,
                        Current_Group, X, Span);
                     if Adjusted_Result.Status /=
                       Storage_Operations.Operation_Ready
                     then
                        return Status_Failure (Adjusted_Result.Status);
                     end if;
                     Adjusted := Adjusted_Result.Value;
                  end if;
                  Outcome := Find_Nearest (Adjusted, Chosen);
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
                  Indexed_Pixels (Indexed_Pixels'First + Index) :=
                    Byte (Chosen);
                  if Use_Dither then
                     Status := Storage_Operations.Diffuse
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

