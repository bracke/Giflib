with Giflib.Errors;
with Giflib.Internal.Quantization_Palette;

package body Giflib.Internal.Quantization_Storage.Histogram_Operations is
   function Charge
     (Work : in out Work_Budgets.Meter;
      Amount : Byte_Count) return Boolean
   is
      Accepted : Boolean;
   begin
      Work_Budgets.Try_Charge (Work, Amount, Accepted);
      return Accepted;
   end Charge;

   function Reset
     (Object : in out Resources;
      Work : in out Work_Budgets.Meter) return Operation_Status is
   begin
      if not Histogram_Allocated (Object) then
         return Operations.Operation_Invariant_Failure;
      end if;
      declare
         Histogram : constant Histogram_Ownership.Element_Access :=
           Histogram_Ownership.Value (Object.Histogram_Data);
      begin
         if not Charge (Work, Byte_Count (Histogram.Counts'Length)) then
            return Operations.Operation_Work_Limit;
         end if;
         Histogram.Counts := [others => 0];
         Histogram.Occupied_Count := 0;
      end;
      return Operations.Operation_Ready;
   end Reset;

   function Add_Sample
     (Object : in out Resources;
      Bucket : Histogram_Index) return Operation_Status
   is
      Palette_Bucket : constant Quantization_Palette.Histogram_Index :=
        Quantization_Palette.Histogram_Index (Bucket);
   begin
      if not Histogram_Allocated (Object) then
         return Operations.Operation_Invariant_Failure;
      end if;
      declare
         Histogram : constant Histogram_Ownership.Element_Access :=
           Histogram_Ownership.Value (Object.Histogram_Data);
      begin
         if Histogram.Counts (Palette_Bucket) = 0 then
            if Histogram.Occupied_Count = Histogram.Occupied'Length then
               return Operations.Operation_Invariant_Failure;
            end if;
            Histogram.Occupied_Count := Histogram.Occupied_Count + 1;
            Histogram.Occupied (Histogram.Occupied_Count) := Palette_Bucket;
         end if;
         if Histogram.Counts (Palette_Bucket) = Natural'Last then
            return Operations.Operation_Invariant_Failure;
         end if;
         Histogram.Counts (Palette_Bucket) :=
           Histogram.Counts (Palette_Bucket) + 1;
      end;
      return Operations.Operation_Ready;
   end Add_Sample;

   function Build_Median_Cut
     (Object : in out Resources;
      Generated_Start : Natural;
      Opaque_Capacity : Natural;
      Work : in out Work_Budgets.Meter;
      Output_Palette : in out Palettes.Palette) return Results.Result is
   begin
      if not Histogram_Allocated (Object) then
         return Results.Failure
           (Errors.Make (Errors.Internal_Invariant_Failed));
      end if;
      return Quantization_Palette.Build_Median_Cut
        (Histogram_Ownership.Value (Object.Histogram_Data).all,
         Generated_Start, Opaque_Capacity, Work, Output_Palette);
   end Build_Median_Cut;
end Giflib.Internal.Quantization_Storage.Histogram_Operations;
