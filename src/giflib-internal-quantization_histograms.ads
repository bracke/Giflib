package Giflib.Internal.Quantization_Histograms is
   pragma Preelaborate;

   subtype Histogram_Index is Natural range 0 .. 32_767;
   type Histogram_Array is array (Histogram_Index) of Natural;
   subtype Occupied_Position is Positive range 1 .. Histogram_Index'Last + 1;
   type Occupied_Array is array (Occupied_Position) of Histogram_Index;

   type Histogram_State is record
      Counts : Histogram_Array := [others => 0];
      Occupied : Occupied_Array := [others => 0];
      Occupied_Count : Natural range 0 .. Occupied_Position'Last := 0;
   end record
     with No_Controlled_Parts => True;

   function Add_Sample
     (Object : in out Histogram_State;
      Bucket : Histogram_Index) return Boolean;
   pragma Inline_Always (Add_Sample);
   function Add_Count
     (Object : in out Histogram_State;
      Bucket : Histogram_Index;
      Amount : Natural) return Boolean;
end Giflib.Internal.Quantization_Histograms;
