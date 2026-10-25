with Giflib.Internal.Quantization_Storage.Outcomes;
with Giflib.Internal.Work_Budgets;

package Giflib.Internal.Quantization_Storage.Cache_Operations is
   pragma Preelaborate;
   use type Outcomes.Budgeted_Status;

   type Probe_Result is record
      Status : Outcomes.Budgeted_Status := Outcomes.Budgeted_Invariant_Failure;
      Found : Boolean := False;
      Value : Palette_Index := 0;
      Store_Slot : Natural := 0;
   end record;

   function Reset
     (Object : in out Resources;
      Work : in out Work_Budgets.Meter) return Outcomes.Budgeted_Status
     with Post =>
       (if Reset'Result = Outcomes.Budgeted_Work_Limit
        then Work_Budgets.Failed (Work));
   function Probe
     (Object : in out Resources;
      Key : Natural;
      Work : in out Work_Budgets.Meter) return Probe_Result
     with Post =>
       (if Probe'Result.Status = Outcomes.Budgeted_Work_Limit
        then Work_Budgets.Failed (Work));
   function Store
     (Object : in out Resources;
      Slot : Natural;
      Key : Natural;
      Value : Palette_Index) return Outcomes.Storage_Status;
end Giflib.Internal.Quantization_Storage.Cache_Operations;
