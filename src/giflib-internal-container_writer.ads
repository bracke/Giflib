with Giflib.Frames;
with Giflib.Internal.Encoding_Arithmetic;
with Giflib.Palettes;
with Giflib.Streams;

package Giflib.Internal.Container_Writer is
   pragma Preelaborate;

   subtype Signature_Data is Streams.Byte_Array (1 .. 6);
   subtype Logical_Screen_Data is Streams.Byte_Array (1 .. 7);
   subtype Image_Descriptor_Data is Streams.Byte_Array (1 .. 10);
   subtype Graphic_Control_Data is Streams.Byte_Array (1 .. 8);
   subtype Color_Resolution_Value is Positive range 1 .. 8;
   subtype Palette_Length is Internal.Encoding_Arithmetic.Palette_Length;

   type Palette_Description (Present : Boolean := False) is record
      case Present is
         when True =>
            Length : Palette_Length;
            Sorted : Boolean := False;
         when False =>
            null;
      end case;
   end record;

   No_Palette : constant Palette_Description := (Present => False);

   function Signature (Version : GIF_Version) return Signature_Data;

   function Logical_Screen
     (Width : Image_Width;
      Height : Image_Height;
      Color_Resolution : Color_Resolution_Value;
      Global_Palette : Palette_Description;
      Background_Index : Palette_Index;
      Pixel_Aspect_Ratio : Byte) return Logical_Screen_Data;

   function Image_Descriptor
     (Left : Coordinate;
      Top : Coordinate;
      Width : Image_Width;
      Height : Image_Height;
      Local_Palette : Palette_Description;
      Interlaced : Boolean) return Image_Descriptor_Data;

   function Graphic_Control
     (Control : Frames.Graphic_Control) return Graphic_Control_Data;

   function Palette_Data
     (Palette : Palettes.Palette) return Streams.Byte_Array
     with Pre => Palette.Length >= Palette_Length'First;
end Giflib.Internal.Container_Writer;
