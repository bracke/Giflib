with Giflib.Internal.Quantization_Dithering;

package body Giflib.Internal.Quantization_Storage.Dither_Operations is
   function Reset
     (Object : in out Resources;
      Required_Length : Positive;
      Work : in out Work_Budgets.Meter) return Outcomes.Budgeted_Status
   is
      Accepted : Boolean;
      procedure Clear (Errors : in out Quantization_Dithering.Error_Array) is
      begin
         Errors (0 .. Required_Length - 1) := [others => 0];
      end Clear;
   begin
      if Error_Length (Object) < Required_Length then
         return Outcomes.Budgeted_Invariant_Failure;
      end if;
      Work_Budgets.Try_Charge
        (Work, Byte_Count (Required_Length), Accepted);
      if not Accepted then
         return Outcomes.Budgeted_Work_Limit;
      end if;
      Error_Ownership.Update (Object.Error_Data, Clear'Access);
      return Outcomes.Budgeted_Ready;
   end Reset;

   function Clear_Next_Row
     (Object : in out Resources;
      Next_Group : Group_Index;
      Span : Error_Span) return Outcomes.Storage_Status
   is
      procedure Clear (Errors : in out Quantization_Dithering.Error_Array) is
      begin
         Quantization_Dithering.Clear_Next_Row
           (Errors, Next_Group, Span);
      end Clear;
   begin
      if Error_Length (Object) < Natural (Span) * 6 then
         return Outcomes.Storage_Invariant_Failure;
      end if;
      Error_Ownership.Update (Object.Error_Data, Clear'Access);
      return Outcomes.Storage_Ready;
   end Clear_Next_Row;

   function Clear_Transparent
     (Object : in out Resources;
      Current_Group : Group_Index;
      X : Natural;
      Span : Error_Span) return Outcomes.Storage_Status
   is
      procedure Clear (Errors : in out Quantization_Dithering.Error_Array) is
      begin
         Quantization_Dithering.Clear_Transparent
           (Errors, Current_Group, X, Span);
      end Clear;
   begin
      if Error_Length (Object) < Natural (Span) * 6
        or else X >= Natural (Span) - 1
      then
         return Outcomes.Storage_Invariant_Failure;
      end if;
      Error_Ownership.Update (Object.Error_Data, Clear'Access);
      return Outcomes.Storage_Ready;
   end Clear_Transparent;

   function Adjust
     (Object : in out Resources;
      Color : Palettes.RGB_Color;
      Current_Group : Group_Index;
      X : Natural;
      Span : Error_Span) return Color_Outcome
   is
      Result : Color_Outcome :=
        (Status => Outcomes.Storage_Invariant_Failure, Value => Color);
      procedure Read (Errors : Quantization_Dithering.Error_Array) is
      begin
         Result :=
           (Status => Outcomes.Storage_Ready,
            Value => Quantization_Dithering.Adjust
              (Color, Errors, Current_Group, X, Span));
      end Read;
   begin
      if Error_Length (Object) < Natural (Span) * 6
        or else X >= Natural (Span) - 1
      then
         return (Status => Outcomes.Storage_Invariant_Failure,
                 Value => Color);
      end if;
      Error_Ownership.Query (Object.Error_Data, Read'Access);
      return Result;
   end Adjust;

   function Diffuse
     (Object : in out Resources;
      Current_Group : Group_Index;
      Next_Group : Group_Index;
      X : Natural;
      Span : Error_Span;
      Adjusted : Palettes.RGB_Color;
      Chosen : Palettes.RGB_Color) return Outcomes.Storage_Status
   is
      procedure Apply (Errors : in out Quantization_Dithering.Error_Array) is
      begin
         Quantization_Dithering.Diffuse
           (Errors,
            Current_Group,
            Next_Group,
            X,
            Span,
            Adjusted,
            Chosen);
      end Apply;
   begin
      if Error_Length (Object) < Natural (Span) * 6
        or else X >= Natural (Span) - 2
      then
         return Outcomes.Storage_Invariant_Failure;
      end if;
      Error_Ownership.Update (Object.Error_Data, Apply'Access);
      return Outcomes.Storage_Ready;
   end Diffuse;
end Giflib.Internal.Quantization_Storage.Dither_Operations;
