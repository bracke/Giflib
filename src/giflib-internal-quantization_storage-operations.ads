with Giflib.Palettes;

package Giflib.Internal.Quantization_Storage.Operations is
   pragma Preelaborate;

   type Operation_Status is
     (Operation_Ready, Operation_Work_Limit, Operation_Invariant_Failure);
   type Cache_Probe_Result is record
      Status : Operation_Status := Operation_Invariant_Failure;
      Found : Boolean := False;
      Value : Palette_Index := 0;
      Store_Slot : Natural := 0;
      Probe_Count : Natural := 0;
   end record;
   type Color_Outcome is record
      Status : Operation_Status := Operation_Invariant_Failure;
      Value : Palettes.RGB_Color := (others => 0);
   end record;

end Giflib.Internal.Quantization_Storage.Operations;
