with Giflib.Errors;
with Giflib.Internal.Quantization_Arithmetic;
with Giflib.Internal.Quantization_Pixels;
with Giflib.Internal.Quantization_Storage.Cache_Operations;
with Giflib.Internal.Quantization_Storage.Outcomes;
with Giflib.Internal.Resource_Diagnostics;

package body Giflib.Internal.Quantization_Mapping is
   package Arithmetic renames Quantization_Arithmetic;
   package Cache renames Quantization_Storage.Cache_Operations;
   package Outcomes renames Quantization_Storage.Outcomes;
   package Pixels renames Quantization_Pixels;
   use type Outcomes.Budgeted_Status;
   use type Outcomes.Storage_Status;

   function Find
     (Object : in out Quantization_Storage.Resources;
      Color : Palettes.RGB_Color;
      Output_Palette : Palettes.Palette;
      First : Natural;
      Exclude_Index : Boolean;
      Excluded_Index : Palette_Index;
      Work : in out Work_Budgets.Meter;
      Chosen : out Palette_Index) return Results.Result
   is
      Key : constant Natural := Pixels.Color_Key (Color);
      Probe : constant Cache.Probe_Result := Cache.Probe (Object, Key, Work);
      Best : Natural := First;
      Best_Distance : Natural := Natural'Last;
      Distance : Natural;
      Accepted : Boolean;
      Status : Outcomes.Storage_Status;

      function Work_Failure return Results.Result is
        (Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               Resource_Diagnostics.With_Work_Limit
                 (Work, Quantization_Work_Limit))));
      function Invariant_Failure return Results.Result is
        (Results.Failure (Errors.Make (Errors.Internal_Invariant_Failed)));
   begin
      Chosen := 0;
      if Probe.Status = Outcomes.Budgeted_Work_Limit then
         return Work_Failure;
      elsif Probe.Status /= Outcomes.Budgeted_Ready then
         return Invariant_Failure;
      elsif Probe.Found then
         Chosen := Probe.Value;
         return Results.Success;
      elsif Output_Palette.Length <= First then
         return Invariant_Failure;
      end if;
      Work_Budgets.Try_Charge
        (Work, Byte_Count (Output_Palette.Length - First), Accepted);
      if not Accepted then
         return Work_Failure;
      end if;
      for I in First .. Output_Palette.Length - 1 loop
         if not (Exclude_Index and then Palette_Index (I) = Excluded_Index) then
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
      Status := Cache.Store (Object, Probe.Store_Slot, Key, Chosen);
      return
        (if Status = Outcomes.Storage_Ready
         then Results.Success else Invariant_Failure);
   end Find;
end Giflib.Internal.Quantization_Mapping;
