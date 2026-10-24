with Giflib.Errors;
with Giflib.Internal.Image_Arithmetic;

package body Giflib.Images is
   use type Internal.Image_Arithmetic.Extent_Status;

   function Bytes_Per_Pixel (Format : Pixel_Format) return Positive is
     (case Format is
         when Indexed_8 => 1,
         when RGB_24 | BGR_24 => 3,
         when RGBA_32 | BGRA_32 => 4);

   function Required_Bytes (View : Image_View; Value : out Byte_Count) return Results.Result is
      Pixel_Bytes : constant Byte_Count := Byte_Count (Bytes_Per_Pixel (View.Format));
      Extent : constant Internal.Image_Arithmetic.Extent_Result :=
        Internal.Image_Arithmetic.Required_Extent
          (View.Width,
           View.Height,
           View.Stride,
           Internal.Image_Arithmetic.Pixel_Byte_Count (Pixel_Bytes));
   begin
      Value := 0;
      if Extent.Status = Internal.Image_Arithmetic.Stride_Too_Short then
         return Results.Failure
           (Errors.Make
              (Errors.Invalid_Dimensions,
               (Expected => Extent.Row_Bytes,
                Actual => Byte_Count (View.Stride),
                others => <>)));
      elsif Extent.Status = Internal.Image_Arithmetic.Extent_Overflow then
         return Results.Failure (Errors.Make (Errors.Integer_Overflow));
      end if;
      Value := Extent.Required_Bytes;
      return Results.Success;
   end Required_Bytes;

   function Validate (View : Image_View) return Results.Result is
      Required : Byte_Count;
      Outcome : constant Results.Result := Required_Bytes (View, Required);
   begin
      if not Results.Succeeded (Outcome) then
         return Outcome;
      elsif View.Accessible_Bytes > Byte_Count (View.Data'Length) then
         return Results.Failure
           (Errors.Make
              (Errors.Invalid_Dimensions,
               (Expected => Byte_Count (View.Data'Length),
                Actual => View.Accessible_Bytes, others => <>)));
      elsif Required > View.Accessible_Bytes then
         return Results.Failure
           (Errors.Make
              (Errors.Invalid_Dimensions,
               (Expected => Required, Actual => View.Accessible_Bytes, others => <>)));
      end if;
      return Results.Success;
   end Validate;
end Giflib.Images;
