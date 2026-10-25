with Giflib.Palettes;
with Giflib.Results;
with Giflib.Internal.Work_Budgets;

package Giflib.Internal.Quantization_Palette is
   pragma Preelaborate;

   subtype Histogram_Index is Natural range 0 .. 32_767;
   type Histogram_Array is array (Histogram_Index) of Natural;
   subtype Occupied_Position is Positive range 1 .. Histogram_Index'Last + 1;
   type Occupied_Array is array (Occupied_Position) of Histogram_Index;
   type Histogram_State is record
      Counts : Histogram_Array := [others => 0];
      Occupied : Occupied_Array := [others => 0];
      Occupied_Count : Natural range 0 .. Occupied_Position'Last := 0;
   end record;

   function Build_Median_Cut
     (Histogram       : in out Histogram_State;
      Generated_Start : Natural;
      Opaque_Capacity : Natural;
      Work            : in out Work_Budgets.Meter;
      Output_Palette  : in out Palettes.Palette) return Results.Result;
end Giflib.Internal.Quantization_Palette;
