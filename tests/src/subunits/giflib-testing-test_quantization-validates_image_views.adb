separate (Giflib.Testing.Test_Quantization)
procedure Validates_Image_Views (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Data : aliased constant Giflib.Streams.Byte_Array := [for I in 1 .. 14 => Giflib.Byte (I)];
   View : Giflib.Images.Image_View :=
     (Format => Giflib.RGB_24, Width => 2, Height => 2, Stride => 8,
      Accessible_Bytes => 14, Data => Data'Access);
   Required : Giflib.Byte_Count;
   Outcome : Giflib.Results.Result;
begin
   Outcome := Giflib.Images.Required_Bytes (View, Required);
   Assert (Giflib.Results.Succeeded (Outcome) and then Required = 14,
           "padded image extent was calculated incorrectly");
   Outcome := Giflib.Images.Validate (View);
   Assert (Giflib.Results.Succeeded (Outcome), "valid padded view was rejected");
   View.Stride := 5;
   Outcome := Giflib.Images.Validate (View);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_Dimensions,
           "short row stride was accepted");
   View.Stride := 8;
   View.Accessible_Bytes := 13;
   Outcome := Giflib.Images.Validate (View);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_Dimensions,
           "short accessible extent was accepted");
   View.Width := 1;
   View.Height := 2;
   View.Stride := Giflib.Row_Stride'Last;
   Outcome := Giflib.Images.Required_Bytes (View, Required);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Integer_Overflow
           and then Required = 0,
           "image extent overflow was accepted");
end Validates_Image_Views;

