with Giflib.Internal.Quantization_Buffer_Arithmetic;
with Giflib.Internal.Quantization_Dithering;
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
   subtype Error_State is Quantization_Dithering.Error_Array;

   function Update
     (Object : in out Resources;
      Process : not null access procedure
        (Errors : in out Error_State)) return Outcomes.Storage_Status;

   function Reset
     (Object : in out Resources;
      Required_Length : Positive;
      Work : in out Work_Budgets.Meter) return Outcomes.Budgeted_Status
     with Post =>
       (if Reset'Result = Outcomes.Budgeted_Work_Limit
        then Work_Budgets.Failed (Work));
   function Clear_Next_Row
     (Errors : in out Error_State;
      Next_Group : Group_Index;
      Span : Error_Span) return Outcomes.Storage_Status;
   function Clear_Next_Row
     (Object : in out Resources;
      Next_Group : Group_Index;
      Span : Error_Span) return Outcomes.Storage_Status;
   function Clear_Transparent
     (Errors : in out Error_State;
      Current_Group : Group_Index;
      X : Natural;
      Span : Error_Span) return Outcomes.Storage_Status;
   procedure Clear_Transparent_Validated
     (Errors : in out Error_State;
      Current_Group : Group_Index;
      X : Natural;
      Span : Error_Span);
   pragma Inline_Always (Clear_Transparent_Validated);
   function Clear_Transparent
     (Object : in out Resources;
      Current_Group : Group_Index;
      X : Natural;
      Span : Error_Span) return Outcomes.Storage_Status;
   function Adjust
     (Errors : Error_State;
      Color : Palettes.RGB_Color;
      Current_Group : Group_Index;
      X : Natural;
      Span : Error_Span) return Color_Outcome;
   function Adjust_Validated
     (Errors : Error_State;
      Color : Palettes.RGB_Color;
      Current_Group : Group_Index;
      X : Natural;
      Span : Error_Span) return Palettes.RGB_Color;
   pragma Inline_Always (Adjust_Validated);
   function Adjust
     (Object : in out Resources;
      Color : Palettes.RGB_Color;
      Current_Group : Group_Index;
      X : Natural;
      Span : Error_Span) return Color_Outcome;
   function Diffuse
     (Errors : in out Error_State;
      Current_Group : Group_Index;
      Next_Group : Group_Index;
      X : Natural;
      Span : Error_Span;
      Adjusted : Palettes.RGB_Color;
      Chosen : Palettes.RGB_Color) return Outcomes.Storage_Status;
   procedure Diffuse_Validated
     (Errors : in out Error_State;
      Current_Group : Group_Index;
      Next_Group : Group_Index;
      X : Natural;
      Span : Error_Span;
      Adjusted : Palettes.RGB_Color;
      Chosen : Palettes.RGB_Color);
   pragma Inline_Always (Diffuse_Validated);
   function Diffuse
     (Object : in out Resources;
      Current_Group : Group_Index;
      Next_Group : Group_Index;
      X : Natural;
      Span : Error_Span;
      Adjusted : Palettes.RGB_Color;
      Chosen : Palettes.RGB_Color) return Outcomes.Storage_Status;
end Giflib.Internal.Quantization_Storage.Dither_Operations;
