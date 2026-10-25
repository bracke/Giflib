with Giflib.Internal.Quantization_Arithmetic;
with Giflib.Internal.Quantization_Buffer_Arithmetic;
with Giflib.Internal.Work_Budgets;
with Giflib.Palettes;
with Giflib.Results;

package Giflib.Internal.Quantization_Storage.Operations is
   pragma Preelaborate;

   subtype Histogram_Index is Quantization_Arithmetic.Histogram_Index;
   subtype Group_Index is Quantization_Buffer_Arithmetic.Group_Index;
   subtype Error_Span is Quantization_Buffer_Arithmetic.Error_Span;
   Nearest_Cache_Capacity : constant Positive := Cache_Capacity;

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

   function Reset_Histogram
     (Object : in out Resources;
      Work : in out Work_Budgets.Meter) return Operation_Status;
   function Add_Histogram_Sample
     (Object : in out Resources;
      Bucket : Histogram_Index) return Operation_Status;
   function Build_Median_Cut
     (Object : in out Resources;
      Generated_Start : Natural;
      Opaque_Capacity : Natural;
      Work : in out Work_Budgets.Meter;
      Output_Palette : in out Palettes.Palette) return Results.Result;

   function Reset_Nearest_Cache
     (Object : in out Resources;
      Work : in out Work_Budgets.Meter) return Operation_Status;
   function Probe_Nearest_Cache
     (Object : in out Resources;
      Key : Natural;
      Start : Natural) return Cache_Probe_Result;
   function Store_Nearest_Cache
     (Object : in out Resources;
      Slot : Natural;
      Key : Natural;
      Value : Palette_Index) return Operation_Status;

   function Reset_Errors
     (Object : in out Resources;
      Required_Length : Positive;
      Work : in out Work_Budgets.Meter) return Operation_Status;
   function Clear_Next_Row
     (Object : in out Resources;
      Next_Group : Group_Index;
      Span : Error_Span) return Operation_Status;
   function Clear_Transparent
     (Object : in out Resources;
      Current_Group : Group_Index;
      X : Natural;
      Span : Error_Span) return Operation_Status;
   function Adjust
     (Object : in out Resources;
      Color : Palettes.RGB_Color;
      Current_Group : Group_Index;
      X : Natural;
      Span : Error_Span) return Color_Outcome;
   function Diffuse
     (Object : in out Resources;
      Current_Group : Group_Index;
      Next_Group : Group_Index;
      X : Natural;
      Span : Error_Span;
      Adjusted : Palettes.RGB_Color;
      Chosen : Palettes.RGB_Color) return Operation_Status;
end Giflib.Internal.Quantization_Storage.Operations;
