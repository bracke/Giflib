with Giflib.Results;
with Giflib.Streams;

package Giflib.Images is
   pragma Preelaborate;

   type Image_View (Data : not null access constant Streams.Byte_Array) is record
      Format : Pixel_Format := RGB_24;
      Width : Image_Width := Image_Width'First;
      Height : Image_Height := Image_Height'First;
      Stride : Row_Stride := 3;
      Accessible_Bytes : Byte_Count := 0;
   end record;

   function Bytes_Per_Pixel (Format : Pixel_Format) return Positive;
   function Required_Bytes (View : Image_View; Value : out Byte_Count) return Results.Result;
   function Validate (View : Image_View) return Results.Result;
end Giflib.Images;
