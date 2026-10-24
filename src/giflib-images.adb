with Giflib.Errors;

package body Giflib.Images is
   use type Streams.Const_Byte_Array_Access;

   function Bytes_Per_Pixel (Format : Pixel_Format) return Positive is
     (case Format is
         when Indexed_8 => 1,
         when RGB_24 | BGR_24 => 3,
         when RGBA_32 | BGRA_32 => 4);

   function Required_Bytes (View : Image_View; Value : out Byte_Count) return Results.Result is
      Pixel_Bytes : constant Byte_Count := Byte_Count (Bytes_Per_Pixel (View.Format));
      Row_Bytes : constant Byte_Count := Byte_Count (View.Width) * Pixel_Bytes;
      Prior_Rows : Byte_Count;
   begin
      Value := 0;
      if Byte_Count (View.Stride) < Row_Bytes then
         return Results.Failure
           (Errors.Make
              (Errors.Invalid_Dimensions,
               (Expected => Row_Bytes, Actual => Byte_Count (View.Stride), others => <>)));
      elsif Byte_Count (View.Height - 1) > 0
        and then Byte_Count (View.Stride) > Byte_Count'Last / Byte_Count (View.Height - 1)
      then
         return Results.Failure (Errors.Make (Errors.Integer_Overflow));
      end if;
      Prior_Rows := Byte_Count (View.Height - 1) * Byte_Count (View.Stride);
      if Row_Bytes > Byte_Count'Last - Prior_Rows then
         return Results.Failure (Errors.Make (Errors.Integer_Overflow));
      end if;
      Value := Prior_Rows + Row_Bytes;
      return Results.Success;
   end Required_Bytes;

   function Validate (View : Image_View) return Results.Result is
      Required : Byte_Count;
      Outcome : constant Results.Result := Required_Bytes (View, Required);
   begin
      if not Results.Succeeded (Outcome) then
         return Outcome;
      elsif View.Data = null then
         return Results.Failure (Errors.Make (Errors.Invalid_Dimensions));
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
