with Giflib.Internal.Quantization_Buffer_Arithmetic;
with Giflib.Palettes;

package Giflib.Internal.Quantization_Dithering is
   pragma Preelaborate;

   package Buffer_Arithmetic renames
     Giflib.Internal.Quantization_Buffer_Arithmetic;

   type Error_Array is array (Natural range <>) of Long_Integer;

   procedure Clear_Next_Row
     (Errors     : in out Error_Array;
      Next_Group : Buffer_Arithmetic.Group_Index;
      Span       : Buffer_Arithmetic.Error_Span);

   procedure Clear_Transparent
     (Errors        : in out Error_Array;
      Current_Group : Buffer_Arithmetic.Group_Index;
      X             : Natural;
      Span          : Buffer_Arithmetic.Error_Span);

   function Adjust
     (Color         : Palettes.RGB_Color;
      Errors        : Error_Array;
      Current_Group : Buffer_Arithmetic.Group_Index;
      X             : Natural;
      Span          : Buffer_Arithmetic.Error_Span) return Palettes.RGB_Color;

   procedure Diffuse
     (Errors        : in out Error_Array;
      Current_Group : Buffer_Arithmetic.Group_Index;
      Next_Group    : Buffer_Arithmetic.Group_Index;
      X             : Natural;
      Span          : Buffer_Arithmetic.Error_Span;
      Adjusted      : Palettes.RGB_Color;
      Chosen        : Palettes.RGB_Color);
end Giflib.Internal.Quantization_Dithering;
