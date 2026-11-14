with Giflib.Internal.Quantization_Storage.Outcomes;
with Giflib.Internal.Work_Budgets;

package Giflib.Internal.Quantization_Storage.Cache_Operations is
   pragma Preelaborate;
   use type Outcomes.Budgeted_Status;

   type Probe_Kind is
     (Probe_Hit, Probe_Miss, Probe_Work_Limit, Probe_Invariant_Failure);
   type Probe_Result (Kind : Probe_Kind := Probe_Invariant_Failure) is record
      case Kind is
         when Probe_Hit =>
            Value : Palette_Index;
         when Probe_Miss =>
            Store_Slot : Natural;
         when Probe_Work_Limit | Probe_Invariant_Failure =>
            null;
      end case;
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
       (if Probe'Result.Kind = Probe_Work_Limit
        then Work_Budgets.Failed (Work));
   function Store
     (Object : in out Resources;
      Slot : Natural;
      Key : Natural;
      Value : Palette_Index) return Outcomes.Storage_Status;
end Giflib.Internal.Quantization_Storage.Cache_Operations;
