with Giflib.Internal.Quantization_Buffer_Arithmetic;
with Giflib.Internal.Quantization_Storage.Outcomes;
with Giflib.Internal.Work_Budgets;
with Giflib.Palettes;

package Giflib.Internal.Quantization_Storage.Dither_Operations is
   pragma Preelaborate;
   use type Outcomes.Budgeted_Status;
   type Color_Outcome is record
      Status : Outcomes.Storage_Status := Outcomes.Storage_Invariant_Failure;
      Value : Palettes.RGB_Color := (others => 0);
   end record;
   subtype Group_Index is Quantization_Buffer_Arithmetic.Group_Index;
   subtype Error_Span is Quantization_Buffer_Arithmetic.Error_Span;

   function Reset
     (Object : in out Resources;
      Required_Length : Positive;
      Work : in out Work_Budgets.Meter) return Outcomes.Budgeted_Status
     with Post =>
       (if Reset'Result = Outcomes.Budgeted_Work_Limit
        then Work_Budgets.Failed (Work));
   function Clear_Next_Row
     (Object : in out Resources;
      Next_Group : Group_Index;
      Span : Error_Span) return Outcomes.Storage_Status;
   function Clear_Transparent
     (Object : in out Resources;
      Current_Group : Group_Index;
      X : Natural;
      Span : Error_Span) return Outcomes.Storage_Status;
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
      Chosen : Palettes.RGB_Color) return Outcomes.Storage_Status;
end Giflib.Internal.Quantization_Storage.Dither_Operations;
