with Giflib.Images;
with Giflib.Palettes;

package Giflib.Internal.Quantization_Pixels is
   pragma Preelaborate;

   type Source_Pixel is record
      Color : Palettes.RGB_Color;
      Alpha : Byte := 255;
   end record;

   type Pixel_Result (Valid : Boolean := False) is record
      case Valid is
         when True =>
            Value : Source_Pixel;
         when False =>
            null;
      end case;
   end record;

   function Read_Pixel
     (Source : Images.Image_View;
      X, Y   : Natural) return Pixel_Result;

   function Row_Start
     (Source : Images.Image_View;
      Y : Natural) return Positive;

   function Read_Validated
     (Source : Images.Image_View;
      Position : Positive) return Source_Pixel;

   function Read_Indexed_8_Validated
     (Source : Images.Image_View;
      Position : Positive) return Source_Pixel;
   function Read_RGB_24_Validated
     (Source : Images.Image_View;
      Position : Positive) return Source_Pixel;
   function Read_BGR_24_Validated
     (Source : Images.Image_View;
      Position : Positive) return Source_Pixel;
   function Read_RGBA_32_Validated
     (Source : Images.Image_View;
      Position : Positive) return Source_Pixel;
   function Read_BGRA_32_Validated
     (Source : Images.Image_View;
      Position : Positive) return Source_Pixel;

   function Is_Transparent
     (Pixel            : Source_Pixel;
      Source_Format    : Pixel_Format;
      Use_Transparency : Boolean;
      Alpha_Threshold  : Byte) return Boolean;

   function Color_Key (Color : Palettes.RGB_Color) return Natural;

   pragma Inline_Always (Read_Validated);
   pragma Inline_Always (Read_Indexed_8_Validated);
   pragma Inline_Always (Read_RGB_24_Validated);
   pragma Inline_Always (Read_BGR_24_Validated);
   pragma Inline_Always (Read_RGBA_32_Validated);
   pragma Inline_Always (Read_BGRA_32_Validated);
   pragma Inline_Always (Is_Transparent);
   pragma Inline_Always (Color_Key);
end Giflib.Internal.Quantization_Pixels;
