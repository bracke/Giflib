with Giflib.Images;
with Giflib.Palettes;

package Giflib.Internal.Quantization_Pixels is
   pragma Preelaborate;

   type Source_Pixel is record
      Color : Palettes.RGB_Color;
      Alpha : Byte := 255;
   end record;

   function Pixel_At
     (Source : Images.Image_View;
      X, Y   : Natural) return Source_Pixel;

   function Is_Transparent
     (Pixel            : Source_Pixel;
      Source_Format    : Pixel_Format;
      Use_Transparency : Boolean;
      Alpha_Threshold  : Byte) return Boolean;

   function Color_Key (Color : Palettes.RGB_Color) return Natural;
   function Cache_Start (Key, Cache_Size : Natural) return Natural;
end Giflib.Internal.Quantization_Pixels;
