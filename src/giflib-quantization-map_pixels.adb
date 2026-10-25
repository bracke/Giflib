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
   Nearest_Cache : Nearest_Cache_Access := null;
   Errors : Error_Array_Access := null;
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

   function Nearest (Color : Palettes.RGB_Color) return Palette_Index is
      First : constant Natural := Generated_Start;
      Best : Natural := First;
      Best_Distance : Natural := Natural'Last;
      Distance : Natural;
      Key : constant Natural := Pixels.Color_Key (Color);
      Start : constant Natural :=
        Pixels.Cache_Start (Key, Nearest_Cache_Size);
      Slot : Natural := Start;
      Store_Slot : Natural := Start;
      Probe_Count : Natural := 0;
   begin
      for Probe in 0 .. Nearest_Cache_Probe_Limit - 1 loop
         Probe_Count := Probe_Count + 1;
         Slot := (Start + Probe) mod Nearest_Cache_Size;
         if not Nearest_Cache (Slot).Used then
            Store_Slot := Slot;
            exit;
         elsif Nearest_Cache (Slot).Key = Key then
            if not Charge (Tracker, Byte_Count (Probe_Count))
            then
               return Palette_Index (Best);
            end if;
            return Nearest_Cache (Slot).Value;
         end if;
      end loop;
      if not Charge (Tracker, Byte_Count (Probe_Count))
        or else not Charge
          (Tracker, Byte_Count (Output_Palette.Length - First))
      then
         return Palette_Index (Best);
      end if;
      for I in First .. Output_Palette.Length - 1 loop
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
      Nearest_Cache (Store_Slot) :=
        (Used => True, Key => Key, Value => Palette_Index (Best));
      return Palette_Index (Best);
   end Nearest;
begin
   Outcome := Ensure_Nearest_Cache (Context, Constraints);
   if not Results.Succeeded (Outcome) then
      return Outcome;
   end if;
   Nearest_Cache := Nearest_Cache_Ownership.Value
     (Context.Resources.Nearest_Cache);
   if not Charge (Tracker, Byte_Count (Nearest_Cache'Length))
   then
      return Work_Failure;
   end if;
   Nearest_Cache.all := [others => (others => <>)];
   if Use_Dither then
      Outcome := Ensure_Error_Buffer
        (Context, Source.Width, Constraints);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      Errors := Error_Ownership.Value (Context.Resources.Errors);
      if not Charge
        (Tracker,
         Byte_Count (Buffer_Arithmetic.Error_Buffer_Length (Source.Width)))
      then
         return Work_Failure;
      end if;
      Errors
        (Errors'First
         .. Errors'First
           + Buffer_Arithmetic.Error_Buffer_Length (Source.Width) - 1) :=
        [others => 0];
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
            Dithering.Clear_Next_Row (Errors.all, Next_Group, Span);
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
                  Dithering.Clear_Transparent
                    (Errors.all, Current_Group, X, Span);
               end if;
            else
               declare
                  Adjusted : Palettes.RGB_Color := Pixel.Color;
                  Chosen : Palette_Index;
               begin
                  if Use_Dither then
                     Adjusted := Dithering.Adjust
                       (Pixel.Color, Errors.all, Current_Group, X, Span);
                  end if;
                  Chosen := Nearest (Adjusted);
                  if Internal.Work_Budgets.Failed (Tracker) then
                     return Work_Failure;
                  end if;
                  Indexed_Pixels (Indexed_Pixels'First + Index) :=
                    Byte (Chosen);
                  if Use_Dither then
                     Dithering.Diffuse
                       (Errors.all,
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

