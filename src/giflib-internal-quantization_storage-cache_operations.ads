with Giflib.Internal.Quantization_Storage.Outcomes;
with Giflib.Internal.Work_Budgets;

package Giflib.Internal.Quantization_Storage.Cache_Operations is
   pragma Preelaborate;
   pragma Warnings
     (Off, "aspect * not enforced on inlined subprogram *");
   use type Outcomes.Budgeted_Status;
   subtype Cache_State is Cache_Array;
   subtype Epoch is Cache_Epoch;
   Probe_Work_Amount : constant Byte_Count := 8;

   function Update
     (Object : in out Resources;
      Process : not null access procedure
        (State : in out Cache_State;
         Current_Epoch : Epoch)) return Outcomes.Storage_Status;

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
     (State : Cache_State;
      Current_Epoch : Epoch;
      Key : Natural;
      Work : in out Work_Budgets.Meter) return Probe_Result
     with Post =>
       (if Probe'Result.Kind = Probe_Work_Limit
        then Work_Budgets.Failed (Work));
   function Probe_Validated
     (State : Cache_State;
      Current_Epoch : Epoch;
      Key : Natural;
      Value : out Palette_Index;
      Store_Slot : out Natural;
      Probe_Work : out Byte_Count) return Probe_Kind
     with Pre => Key <= 16#FF_FF_FF#,
          Post => Probe_Validated'Result in Probe_Hit | Probe_Miss
                  and then Probe_Work in 1 .. Probe_Work_Amount
                  and then Store_Slot < Cache_Capacity;
   function Probe
     (Object : in out Resources;
      Key : Natural;
      Work : in out Work_Budgets.Meter) return Probe_Result
     with Post =>
       (if Probe'Result.Kind = Probe_Work_Limit
        then Work_Budgets.Failed (Work));
   function Store
     (State : in out Cache_State;
      Current_Epoch : Epoch;
      Slot : Natural;
      Key : Natural;
      Value : Palette_Index) return Outcomes.Storage_Status;
   function Store
     (Object : in out Resources;
      Slot : Natural;
      Key : Natural;
      Value : Palette_Index) return Outcomes.Storage_Status;

   pragma Inline_Always (Probe_Validated);
   pragma Warnings
     (On, "aspect * not enforced on inlined subprogram *");
end Giflib.Internal.Quantization_Storage.Cache_Operations;
