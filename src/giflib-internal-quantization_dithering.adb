package body Giflib.Internal.Quantization_Dithering is
   function Clamp (Value : Long_Integer) return Byte is
     (if Value < 0 then 0 elsif Value > 255 then 255 else Byte (Value));

   procedure Clear_Next_Row
     (Errors     : in out Error_Array;
      Next_Group : Buffer_Arithmetic.Group_Index;
      Span       : Buffer_Arithmetic.Error_Span)
   is
      First : constant Natural := Natural (Next_Group) * 3 * Natural (Span);
      Last : constant Natural := First + 3 * Natural (Span) - 1;
   begin
      Errors (First .. Last) := [others => 0];
   end Clear_Next_Row;

   procedure Clear_Transparent
     (Errors        : in out Error_Array;
      Current_Group : Buffer_Arithmetic.Group_Index;
      X             : Natural;
      Span          : Buffer_Arithmetic.Error_Span)
   is
      Position : Natural :=
        Natural (Current_Group) * 3 * Natural (Span) + X + 1;
   begin
      for Channel in 0 .. 2 loop
         Errors (Position) := 0;
         Position := Position + Natural (Span);
      end loop;
   end Clear_Transparent;

   function Adjust
     (Color         : Palettes.RGB_Color;
      Errors        : Error_Array;
      Current_Group : Buffer_Arithmetic.Group_Index;
      X             : Natural;
      Span          : Buffer_Arithmetic.Error_Span) return Palettes.RGB_Color
   is
      Base : constant Natural :=
        Natural (Current_Group) * 3 * Natural (Span) + X + 1;
   begin
      return
        (Clamp
           (Long_Integer (Color.Red) + Errors (Base) / 16),
         Clamp
           (Long_Integer (Color.Green)
            + Errors (Base + Natural (Span)) / 16),
         Clamp
           (Long_Integer (Color.Blue)
            + Errors (Base + 2 * Natural (Span)) / 16));
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
      Current_Position : Natural :=
        Natural (Current_Group) * 3 * Natural (Span) + X + 2;
      Next_Position : Natural :=
        Natural (Next_Group) * 3 * Natural (Span) + X;
   begin
      for Channel in 0 .. 2 loop
         Errors (Current_Position) :=
           Errors (Current_Position) + Error_Delta (Channel) * 7;
         Errors (Next_Position) :=
           Errors (Next_Position) + Error_Delta (Channel) * 3;
         Errors (Next_Position + 1) :=
           Errors (Next_Position + 1) + Error_Delta (Channel) * 5;
         Errors (Next_Position + 2) :=
           Errors (Next_Position + 2) + Error_Delta (Channel);
         Current_Position := Current_Position + Natural (Span);
         Next_Position := Next_Position + Natural (Span);
      end loop;
   end Diffuse;
end Giflib.Internal.Quantization_Dithering;
