with Giflib.Internal.Quantization_Arithmetic;

package body Giflib.Internal.Quantization_Dithering is
   package Arithmetic renames Giflib.Internal.Quantization_Arithmetic;

   procedure Clear_Next_Row
     (Errors     : in out Error_Array;
      Next_Group : Buffer_Arithmetic.Group_Index;
      Span       : Buffer_Arithmetic.Error_Span)
   is
   begin
      for Channel in 0 .. 2 loop
         for X in 0 .. Span - 1 loop
            Errors
              (Buffer_Arithmetic.Error_Index
                 (Next_Group, Channel, X, Span)) := 0;
         end loop;
      end loop;
   end Clear_Next_Row;

   procedure Clear_Transparent
     (Errors        : in out Error_Array;
      Current_Group : Buffer_Arithmetic.Group_Index;
      X             : Natural;
      Span          : Buffer_Arithmetic.Error_Span)
   is
   begin
      for Channel in 0 .. 2 loop
         Errors
           (Buffer_Arithmetic.Error_Index
              (Current_Group, Channel, X + 1, Span)) := 0;
      end loop;
   end Clear_Transparent;

   function Adjust
     (Color         : Palettes.RGB_Color;
      Errors        : Error_Array;
      Current_Group : Buffer_Arithmetic.Group_Index;
      X             : Natural;
      Span          : Buffer_Arithmetic.Error_Span) return Palettes.RGB_Color
   is
   begin
      return
        (Arithmetic.Clamp
           (Long_Integer (Color.Red)
            + Errors
                (Buffer_Arithmetic.Error_Index
                   (Current_Group, 0, X + 1, Span)) / 16),
         Arithmetic.Clamp
           (Long_Integer (Color.Green)
            + Errors
                (Buffer_Arithmetic.Error_Index
                   (Current_Group, 1, X + 1, Span)) / 16),
         Arithmetic.Clamp
           (Long_Integer (Color.Blue)
            + Errors
                (Buffer_Arithmetic.Error_Index
                   (Current_Group, 2, X + 1, Span)) / 16));
   end Adjust;

   procedure Diffuse
     (Errors        : in out Error_Array;
      Current_Group : Buffer_Arithmetic.Group_Index;
      Next_Group    : Buffer_Arithmetic.Group_Index;
      X             : Natural;
      Span          : Buffer_Arithmetic.Error_Span;
      Adjusted      : Palettes.RGB_Color;
      Chosen        : Palettes.RGB_Color)
   is
      Error_Delta : constant array (Natural range 0 .. 2) of Long_Integer :=
        [Long_Integer (Adjusted.Red) - Long_Integer (Chosen.Red),
         Long_Integer (Adjusted.Green) - Long_Integer (Chosen.Green),
         Long_Integer (Adjusted.Blue) - Long_Integer (Chosen.Blue)];
   begin
      for Channel in 0 .. 2 loop
         Errors
           (Buffer_Arithmetic.Error_Index
              (Current_Group, Channel, X + 2, Span)) :=
           Errors
             (Buffer_Arithmetic.Error_Index
                (Current_Group, Channel, X + 2, Span))
           + Error_Delta (Channel) * 7;
         Errors
           (Buffer_Arithmetic.Error_Index
              (Next_Group, Channel, X, Span)) :=
           Errors
             (Buffer_Arithmetic.Error_Index
                (Next_Group, Channel, X, Span))
           + Error_Delta (Channel) * 3;
         Errors
           (Buffer_Arithmetic.Error_Index
              (Next_Group, Channel, X + 1, Span)) :=
           Errors
             (Buffer_Arithmetic.Error_Index
                (Next_Group, Channel, X + 1, Span))
           + Error_Delta (Channel) * 5;
         Errors
           (Buffer_Arithmetic.Error_Index
              (Next_Group, Channel, X + 2, Span)) :=
           Errors
             (Buffer_Arithmetic.Error_Index
                (Next_Group, Channel, X + 2, Span))
           + Error_Delta (Channel);
      end loop;
   end Diffuse;
end Giflib.Internal.Quantization_Dithering;
