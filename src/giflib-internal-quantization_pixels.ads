with Giflib.Images;
with Giflib.Palettes;

package Giflib.Internal.Quantization_Pixels is
   pragma Preelaborate;

   type Source_Pixel is record
      Color : Palettes.RGB_Color;
      Alpha : Byte := 255;
   end record;

   type Pixel_Result is record
      Valid : Boolean := False;
      Value : Source_Pixel := (Color => (others => 0), Alpha => 255);
   end record;

   function Read_Pixel
     (Source : Images.Image_View;
      X, Y   : Natural) return Pixel_Result;

   function Is_Transparent
     (Pixel            : Source_Pixel;
      Source_Format    : Pixel_Format;
      Use_Transparency : Boolean;
      Alpha_Threshold  : Byte) return Boolean;

   function Color_Key (Color : Palettes.RGB_Color) return Natural;
end Giflib.Internal.Quantization_Pixels;
