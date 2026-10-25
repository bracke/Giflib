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

   function Reset_Histogram
     (Object : in out Resources;
      Work : in out Work_Budgets.Meter) return Boolean;
   procedure Add_Histogram_Sample
     (Object : in out Resources;
      Bucket : Histogram_Index);
   function Build_Median_Cut
     (Object : in out Resources;
      Generated_Start : Natural;
      Opaque_Capacity : Natural;
      Work : in out Work_Budgets.Meter;
      Output_Palette : in out Palettes.Palette) return Results.Result;

   function Reset_Nearest_Cache
     (Object : in out Resources;
      Work : in out Work_Budgets.Meter) return Boolean;
   function Nearest
     (Object : in out Resources;
      Color : Palettes.RGB_Color;
      Output_Palette : Palettes.Palette;
      First : Natural;
      Exclude_Index : Boolean;
      Excluded_Index : Palette_Index;
      Work : in out Work_Budgets.Meter) return Palette_Index;

   function Reset_Errors
     (Object : in out Resources;
      Required_Length : Positive;
      Work : in out Work_Budgets.Meter) return Boolean;
   procedure Clear_Next_Row
     (Object : in out Resources;
      Next_Group : Group_Index;
      Span : Error_Span);
   procedure Clear_Transparent
     (Object : in out Resources;
      Current_Group : Group_Index;
      X : Natural;
      Span : Error_Span);
   function Adjust
     (Object : in out Resources;
      Color : Palettes.RGB_Color;
      Current_Group : Group_Index;
      X : Natural;
      Span : Error_Span) return Palettes.RGB_Color;
   procedure Diffuse
     (Object : in out Resources;
      Current_Group : Group_Index;
      Next_Group : Group_Index;
      X : Natural;
      Span : Error_Span;
      Adjusted : Palettes.RGB_Color;
      Chosen : Palettes.RGB_Color);
end Giflib.Internal.Quantization_Storage.Operations;
