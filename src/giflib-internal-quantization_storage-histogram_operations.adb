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
      Work : in out Work_Budgets.Meter) return Outcomes.Budgeted_Status
   is
      procedure Clear
        (Histogram : in out Quantization_Palette.Histogram_State) is
      begin
         Histogram.Counts := [others => 0];
         Histogram.Occupied_Count := 0;
      end Clear;
   begin
      if not Histogram_Allocated (Object) then
         return Outcomes.Budgeted_Invariant_Failure;
      end if;
      if not Charge
        (Work, Byte_Count (Quantization_Palette.Histogram_Array'Length))
      then
         return Outcomes.Budgeted_Work_Limit;
      end if;
      Histogram_Ownership.Update (Object.Histogram_Data, Clear'Access);
      return Outcomes.Budgeted_Ready;
   end Reset;

   function Add_Sample
     (Object : in out Resources;
      Bucket : Histogram_Index) return Outcomes.Storage_Status
   is
      Palette_Bucket : constant Quantization_Palette.Histogram_Index :=
        Quantization_Palette.Histogram_Index (Bucket);
      Result : Outcomes.Storage_Status :=
        Outcomes.Storage_Invariant_Failure;
      procedure Add
        (Histogram : in out Quantization_Palette.Histogram_State) is
      begin
         if Histogram.Counts (Palette_Bucket) = 0 then
            if Histogram.Occupied_Count = Histogram.Occupied'Length then
               return;
            end if;
            Histogram.Occupied_Count := Histogram.Occupied_Count + 1;
            Histogram.Occupied (Histogram.Occupied_Count) := Palette_Bucket;
         end if;
         if Histogram.Counts (Palette_Bucket) = Natural'Last then
            return;
         end if;
         Histogram.Counts (Palette_Bucket) :=
           Histogram.Counts (Palette_Bucket) + 1;
         Result := Outcomes.Storage_Ready;
      end Add;
   begin
      if not Histogram_Allocated (Object) then
         return Outcomes.Storage_Invariant_Failure;
      end if;
      Histogram_Ownership.Update (Object.Histogram_Data, Add'Access);
      return Result;
   end Add_Sample;

   function Build_Median_Cut
     (Object : in out Resources;
      Generated_Start : Natural;
      Opaque_Capacity : Natural;
      Work : in out Work_Budgets.Meter;
      Output_Palette : in out Palettes.Palette) return Results.Result
   is
      Outcome : Results.Result;
      procedure Build
        (Histogram : in out Quantization_Palette.Histogram_State) is
      begin
         Outcome := Quantization_Palette.Build_Median_Cut
           (Histogram,
            Generated_Start,
            Opaque_Capacity,
            Work,
            Output_Palette);
      end Build;
   begin
      if not Histogram_Allocated (Object) then
         return Results.Failure
           (Errors.Make (Errors.Internal_Invariant_Failed));
      end if;
      Histogram_Ownership.Update (Object.Histogram_Data, Build'Access);
      return Outcome;
   end Build_Median_Cut;
end Giflib.Internal.Quantization_Storage.Histogram_Operations;
