with Giflib.Errors;
with Giflib.Internal.Quantization_Palette;

package body Giflib.Internal.Quantization_Storage.Histogram_Operations is
   function Update
     (Object : in out Resources;
      Process : not null access procedure
        (Value : in out Histogram_State)) return Outcomes.Storage_Status
   is
   begin
      if not Histogram_Allocated (Object) then
         return Outcomes.Storage_Invariant_Failure;
      end if;
      Histogram_Ownership.Update (Object.Histogram_Data, Process);
      return Outcomes.Storage_Ready;
   end Update;

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
      Active_Count : Natural := 0;
      procedure Read_Count
        (Histogram : Quantization_Histograms.Histogram_State) is
      begin
         Active_Count := Histogram.Occupied_Count;
      end Read_Count;
      procedure Clear
        (Histogram : in out Quantization_Histograms.Histogram_State) is
      begin
         for Position in 1 .. Histogram.Occupied_Count loop
            Histogram.Counts (Histogram.Occupied (Position)) := 0;
         end loop;
         Histogram.Occupied_Count := 0;
      end Clear;
   begin
      if not Histogram_Allocated (Object) then
         return Outcomes.Budgeted_Invariant_Failure;
      end if;
      Histogram_Ownership.Query (Object.Histogram_Data, Read_Count'Access);
      if not Charge (Work, Byte_Count (Active_Count)) then
         return Outcomes.Budgeted_Work_Limit;
      end if;
      Histogram_Ownership.Update (Object.Histogram_Data, Clear'Access);
      return Outcomes.Budgeted_Ready;
   end Reset;

   function Add_Sample
     (Object : in out Resources;
      Bucket : Histogram_Index) return Outcomes.Storage_Status
   is
      Palette_Bucket : constant Quantization_Histograms.Histogram_Index :=
        Quantization_Histograms.Histogram_Index (Bucket);
      Result : Outcomes.Storage_Status :=
        Outcomes.Storage_Invariant_Failure;
      procedure Add
        (Histogram : in out Quantization_Histograms.Histogram_State) is
      begin
         if Quantization_Histograms.Add_Sample
           (Histogram, Palette_Bucket)
         then
            Result := Outcomes.Storage_Ready;
         end if;
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
        (Histogram : in out Quantization_Histograms.Histogram_State) is
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
