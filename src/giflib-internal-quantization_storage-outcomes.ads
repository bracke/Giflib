package Giflib.Internal.Quantization_Storage.Outcomes is
   pragma Preelaborate;

   type Storage_Status is
     (Storage_Ready, Storage_Invariant_Failure);

   type Budgeted_Status is
     (Budgeted_Ready, Budgeted_Work_Limit, Budgeted_Invariant_Failure);
end Giflib.Internal.Quantization_Storage.Outcomes;
