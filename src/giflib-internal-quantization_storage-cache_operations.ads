with Giflib.Internal.Quantization_Storage.Operations;
with Giflib.Internal.Work_Budgets;

package Giflib.Internal.Quantization_Storage.Cache_Operations is
   pragma Preelaborate;
   use type Operations.Operation_Status;
   subtype Operation_Status is Operations.Operation_Status;
   subtype Probe_Result is Operations.Cache_Probe_Result;

   function Reset
     (Object : in out Resources;
      Work : in out Work_Budgets.Meter) return Operation_Status
     with Post =>
       (if Reset'Result = Operations.Operation_Work_Limit
        then Work_Budgets.Failed (Work));
   function Probe
     (Object : in out Resources;
      Key : Natural) return Probe_Result
     with Post => Probe'Result.Status /= Operations.Operation_Work_Limit;
   function Store
     (Object : in out Resources;
      Slot : Natural;
      Key : Natural;
      Value : Palette_Index) return Operation_Status
     with Post => Store'Result /= Operations.Operation_Work_Limit;
end Giflib.Internal.Quantization_Storage.Cache_Operations;
