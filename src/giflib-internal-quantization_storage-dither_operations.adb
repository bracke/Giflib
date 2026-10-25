with Giflib.Internal.Quantization_Dithering;

package body Giflib.Internal.Quantization_Storage.Dither_Operations is
   function Reset
     (Object : in out Resources;
      Required_Length : Positive;
      Work : in out Work_Budgets.Meter) return Operation_Status
   is
      Accepted : Boolean;
   begin
      if Error_Length (Object) < Required_Length then
         return Operations.Operation_Invariant_Failure;
      end if;
      Work_Budgets.Try_Charge
        (Work, Byte_Count (Required_Length), Accepted);
      if not Accepted then
         return Operations.Operation_Work_Limit;
      end if;
      Error_Ownership.Value (Object.Error_Data).all
        (0 .. Required_Length - 1) := [others => 0];
      return Operations.Operation_Ready;
   end Reset;

   function Clear_Next_Row
     (Object : in out Resources;
      Next_Group : Group_Index;
      Span : Error_Span) return Operation_Status is
   begin
      if Error_Length (Object) < Natural (Span) * 6 then
         return Operations.Operation_Invariant_Failure;
      end if;
      Quantization_Dithering.Clear_Next_Row
        (Error_Ownership.Value (Object.Error_Data).all, Next_Group, Span);
      return Operations.Operation_Ready;
   end Clear_Next_Row;

   function Clear_Transparent
     (Object : in out Resources;
      Current_Group : Group_Index;
      X : Natural;
      Span : Error_Span) return Operation_Status is
   begin
      if Error_Length (Object) < Natural (Span) * 6
        or else X >= Natural (Span) - 1
      then
         return Operations.Operation_Invariant_Failure;
      end if;
      Quantization_Dithering.Clear_Transparent
        (Error_Ownership.Value (Object.Error_Data).all,
         Current_Group, X, Span);
      return Operations.Operation_Ready;
   end Clear_Transparent;

   function Adjust
     (Object : in out Resources;
      Color : Palettes.RGB_Color;
      Current_Group : Group_Index;
      X : Natural;
      Span : Error_Span) return Color_Outcome is
   begin
      if Error_Length (Object) < Natural (Span) * 6
        or else X >= Natural (Span) - 1
      then
         return (Status => Operations.Operation_Invariant_Failure,
                 Value => Color);
      end if;
      return
        (Status => Operations.Operation_Ready,
         Value => Quantization_Dithering.Adjust
           (Color, Error_Ownership.Value (Object.Error_Data).all,
            Current_Group, X, Span));
   end Adjust;

   function Diffuse
     (Object : in out Resources;
      Current_Group : Group_Index;
      Next_Group : Group_Index;
      X : Natural;
      Span : Error_Span;
      Adjusted : Palettes.RGB_Color;
      Chosen : Palettes.RGB_Color) return Operation_Status is
   begin
      if Error_Length (Object) < Natural (Span) * 6
        or else X >= Natural (Span) - 2
      then
         return Operations.Operation_Invariant_Failure;
      end if;
      Quantization_Dithering.Diffuse
        (Error_Ownership.Value (Object.Error_Data).all,
         Current_Group, Next_Group, X, Span, Adjusted, Chosen);
      return Operations.Operation_Ready;
   end Diffuse;
end Giflib.Internal.Quantization_Storage.Dither_Operations;
