with Giflib.Errors;
with Giflib.Internal.Quantization_Box_Operations;
with Giflib.Internal.Resource_Diagnostics;

package body Giflib.Internal.Quantization_Palette is
   package Boxes renames Giflib.Internal.Quantization_Box_Operations;
   use type Boxes.Box_Result_Kind;
   use type Boxes.Split_Result_Kind;
   use type Boxes.Representative_Result_Kind;

   function Build_Median_Cut
     (Histogram       : in out Quantization_Histograms.Histogram_State;
      Generated_Start : Natural;
      Opaque_Capacity : Natural;
      Work            : in out Work_Budgets.Meter;
      Output_Palette  : in out Palettes.Palette) return Results.Result
   is
      Items : Boxes.Box_Array;
      Box_Count : Natural := 0;
      Choice : Natural;
      Best_Range : Natural;
   begin
      if Opaque_Capacity = 0
        or else Generated_Start > 255
        or else Opaque_Capacity > 256 - Generated_Start
        or else Histogram.Occupied_Count = 0
      then
         return Results.Failure
           (Errors.Make (Errors.Internal_Invariant_Failed));
      end if;

      declare
         Initial : constant Boxes.Box_Result :=
           Boxes.Analyze
             (Histogram, 1, Histogram.Occupied_Count, Work);
      begin
         if Initial.Kind = Boxes.Box_Ready then
            Items (0) := Initial.Value;
            Box_Count := 1;
         elsif Initial.Kind = Boxes.Box_Work_Limit then
            return Results.Failure
              (Errors.Make
                 (Errors.Limit_Exceeded,
                  Resource_Diagnostics.With_Work_Limit
                    (Work, Quantization_Work_Limit)));
         else
            return Results.Failure
              (Errors.Make (Errors.Internal_Invariant_Failed));
         end if;
      end;

      while Box_Count < Opaque_Capacity
        and then not Work_Budgets.Failed (Work)
      loop
         Choice := Box_Count;
         Best_Range := 0;
         for Index in 0 .. Box_Count - 1 loop
            declare
               Current_Range : constant Natural :=
                 Boxes.Spread (Items (Index));
            begin
               if Current_Range > Best_Range then
                  Best_Range := Current_Range;
                  Choice := Index;
               end if;
            end;
         end loop;
         exit when Choice = Box_Count or else Best_Range = 0;
         declare
            Division : constant Boxes.Split_Result :=
              Boxes.Split (Histogram, Items (Choice), Work);
         begin
            case Division.Kind is
               when Boxes.Split_Ready =>
                  Items (Choice) := Division.Left;
                  Items (Box_Count) := Division.Right;
                  Box_Count := Box_Count + 1;
               when Boxes.Split_Unavailable =>
                  exit;
               when Boxes.Split_Work_Limit =>
                  return Results.Failure
                    (Errors.Make
                       (Errors.Limit_Exceeded,
                        Resource_Diagnostics.With_Work_Limit
                          (Work, Quantization_Work_Limit)));
            end case;
         end;
      end loop;

      if Work_Budgets.Failed (Work) then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               Resource_Diagnostics.With_Work_Limit
                 (Work, Quantization_Work_Limit)));
      end if;
      for Index in 0 .. Box_Count - 1 loop
         declare
            Color : constant Boxes.Representative_Result :=
              Boxes.Representative (Histogram, Items (Index), Work);
         begin
            if Color.Kind = Boxes.Representative_Work_Limit then
               return Results.Failure
                 (Errors.Make
                    (Errors.Limit_Exceeded,
                     Resource_Diagnostics.With_Work_Limit
                       (Work, Quantization_Work_Limit)));
            elsif Color.Kind = Boxes.Representative_Empty then
               return Results.Failure
                 (Errors.Make (Errors.Internal_Invariant_Failed));
            end if;
            Output_Palette.Colors
              (Palette_Index (Generated_Start + Index)) := Color.Value;
         end;
      end loop;
      if Work_Budgets.Failed (Work) then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               Resource_Diagnostics.With_Work_Limit
                 (Work, Quantization_Work_Limit)));
      end if;
      Output_Palette.Length := Generated_Start + Box_Count;
      return Results.Success;
   end Build_Median_Cut;
end Giflib.Internal.Quantization_Palette;
