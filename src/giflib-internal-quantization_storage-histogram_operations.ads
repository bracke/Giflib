with Giflib.Internal.Quantization_Arithmetic;
with Giflib.Internal.Quantization_Histograms;
with Giflib.Internal.Quantization_Storage.Outcomes;
with Giflib.Internal.Work_Budgets;
with Giflib.Palettes;
with Giflib.Results;

package Giflib.Internal.Quantization_Storage.Histogram_Operations is
   pragma Preelaborate;
   use type Outcomes.Budgeted_Status;
   subtype Histogram_Index is Quantization_Arithmetic.Histogram_Index;
   subtype Histogram_State is Quantization_Histograms.Histogram_State;

   function Update
     (Object : in out Resources;
      Process : not null access procedure
        (Value : in out Histogram_State)) return Outcomes.Storage_Status;

   function Reset
     (Object : in out Resources;
      Work : in out Work_Budgets.Meter) return Outcomes.Budgeted_Status
     with Post =>
       (if Reset'Result = Outcomes.Budgeted_Work_Limit
        then Work_Budgets.Failed (Work));
   function Add_Sample
     (Object : in out Resources;
      Bucket : Histogram_Index) return Outcomes.Storage_Status;
   function Build_Median_Cut
     (Object : in out Resources;
      Generated_Start : Natural;
      Opaque_Capacity : Natural;
      Work : in out Work_Budgets.Meter;
      Output_Palette : in out Palettes.Palette) return Results.Result;
end Giflib.Internal.Quantization_Storage.Histogram_Operations;
