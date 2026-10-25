with Giflib.Internal.Quantization_Buffer_Arithmetic;
with Giflib.Internal.Quantization_Storage.Operations;
with Giflib.Internal.Work_Budgets;
with Giflib.Palettes;

package Giflib.Internal.Quantization_Storage.Dither_Operations is
   pragma Preelaborate;
   use type Operations.Operation_Status;
   subtype Operation_Status is Operations.Operation_Status;
   subtype Color_Outcome is Operations.Color_Outcome;
   subtype Group_Index is Quantization_Buffer_Arithmetic.Group_Index;
   subtype Error_Span is Quantization_Buffer_Arithmetic.Error_Span;

   function Reset
     (Object : in out Resources;
      Required_Length : Positive;
      Work : in out Work_Budgets.Meter) return Operation_Status
     with Post =>
       (if Reset'Result = Operations.Operation_Work_Limit
        then Work_Budgets.Failed (Work));
   function Clear_Next_Row
     (Object : in out Resources;
      Next_Group : Group_Index;
      Span : Error_Span) return Operation_Status
     with Post => Clear_Next_Row'Result /= Operations.Operation_Work_Limit;
   function Clear_Transparent
     (Object : in out Resources;
      Current_Group : Group_Index;
      X : Natural;
      Span : Error_Span) return Operation_Status
     with Post => Clear_Transparent'Result /= Operations.Operation_Work_Limit;
   function Adjust
     (Object : in out Resources;
      Color : Palettes.RGB_Color;
      Current_Group : Group_Index;
      X : Natural;
      Span : Error_Span) return Color_Outcome
     with Post => Adjust'Result.Status /= Operations.Operation_Work_Limit;
   function Diffuse
     (Object : in out Resources;
      Current_Group : Group_Index;
      Next_Group : Group_Index;
      X : Natural;
      Span : Error_Span;
      Adjusted : Palettes.RGB_Color;
      Chosen : Palettes.RGB_Color) return Operation_Status
     with Post => Diffuse'Result /= Operations.Operation_Work_Limit;
end Giflib.Internal.Quantization_Storage.Dither_Operations;
