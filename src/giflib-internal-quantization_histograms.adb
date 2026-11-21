package body Giflib.Internal.Quantization_Histograms is
   function Add_Sample
     (Object : in out Histogram_State;
      Bucket : Histogram_Index) return Boolean
   is
      Current : constant Natural := Object.Counts (Bucket);
   begin
      if Current = 0 then
         if Object.Occupied_Count = Object.Occupied'Length then
            return False;
         end if;
         Object.Occupied_Count := Object.Occupied_Count + 1;
         Object.Occupied (Object.Occupied_Count) := Bucket;
      elsif Current = Natural'Last then
         return False;
      end if;
      Object.Counts (Bucket) := Current + 1;
      return True;
   end Add_Sample;

   function Add_Count
     (Object : in out Histogram_State;
      Bucket : Histogram_Index;
      Amount : Natural) return Boolean
   is
   begin
      if Amount = 0 then
         return True;
      end if;
      if Object.Counts (Bucket) = 0 then
         if Object.Occupied_Count = Object.Occupied'Length then
            return False;
         end if;
         Object.Occupied_Count := Object.Occupied_Count + 1;
         Object.Occupied (Object.Occupied_Count) := Bucket;
      end if;
      if Amount > Natural'Last - Object.Counts (Bucket) then
         return False;
      end if;
      Object.Counts (Bucket) := Object.Counts (Bucket) + Amount;
      return True;
   end Add_Count;
end Giflib.Internal.Quantization_Histograms;
