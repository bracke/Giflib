with Giflib.Internal.Quantization_Arithmetic;
with Giflib.Internal.Quantization_Storage.Outcomes;
with Giflib.Internal.Work_Budgets;
with Giflib.Palettes;
with Giflib.Results;

package Giflib.Internal.Quantization_Storage.Histogram_Operations is
   pragma Preelaborate;
   use type Outcomes.Budgeted_Status;
   subtype Histogram_Index is Quantization_Arithmetic.Histogram_Index;

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
