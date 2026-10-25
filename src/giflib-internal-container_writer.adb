with Giflib.Internal.Descriptor_Arithmetic;
with Giflib.Internal.Extension_Arithmetic;
with Giflib.Internal.Wire_Format;

package body Giflib.Internal.Container_Writer is
   package Descriptor_Arithmetic renames Internal.Descriptor_Arithmetic;
   package Encoding_Arithmetic renames Internal.Encoding_Arithmetic;

   function Encoded_Length (Length : Palette_Length) return Natural is
     (Natural
        (Encoding_Arithmetic.Encoded_Palette_Length
           (Length)));

   function Size_Code (Length : Palette_Length)
      return Descriptor_Arithmetic.Palette_Size_Code
   is
     (Descriptor_Arithmetic.Palette_Size_Code
        (Encoding_Arithmetic.Size_Code
           (Encoding_Arithmetic.Palette_Length (Encoded_Length (Length)))));

   function Signature (Version : GIF_Version) return Signature_Data is
     (if Version = GIF87a
      then [71, 73, 70, 56, 55, 97]
      else [71, 73, 70, 56, 57, 97]);

   function Logical_Screen
     (Width : Image_Width;
      Height : Image_Height;
      Color_Resolution : Color_Resolution_Value;
      Global_Palette : Palette_Description;
      Background_Index : Palette_Index;
      Pixel_Aspect_Ratio : Byte) return Logical_Screen_Data
   is
      Code : constant Descriptor_Arithmetic.Palette_Size_Code :=
        (if Global_Palette.Present then Size_Code (Global_Palette.Length) else 0);
   begin
      return
        [Extension_Arithmetic.Low_Byte (Natural (Width)),
         Extension_Arithmetic.High_Byte (Natural (Width)),
         Extension_Arithmetic.Low_Byte (Natural (Height)),
         Extension_Arithmetic.High_Byte (Natural (Height)),
         Descriptor_Arithmetic.Encode_Logical_Screen
           (Descriptor_Arithmetic.Color_Resolution (Color_Resolution),
            Global_Palette.Present,
            (if Global_Palette.Present then Global_Palette.Sorted else False),
            Code),
         Byte (Background_Index),
         Pixel_Aspect_Ratio];
   end Logical_Screen;

   function Image_Descriptor
     (Left : Coordinate;
      Top : Coordinate;
      Width : Image_Width;
      Height : Image_Height;
      Local_Palette : Palette_Description;
      Interlaced : Boolean) return Image_Descriptor_Data
   is
      Code : constant Descriptor_Arithmetic.Palette_Size_Code :=
        (if Local_Palette.Present then Size_Code (Local_Palette.Length) else 0);
   begin
      return
        [Wire_Format.Image_Separator,
         Extension_Arithmetic.Low_Byte (Natural (Left)),
         Extension_Arithmetic.High_Byte (Natural (Left)),
         Extension_Arithmetic.Low_Byte (Natural (Top)),
         Extension_Arithmetic.High_Byte (Natural (Top)),
         Extension_Arithmetic.Low_Byte (Natural (Width)),
         Extension_Arithmetic.High_Byte (Natural (Width)),
         Extension_Arithmetic.Low_Byte (Natural (Height)),
         Extension_Arithmetic.High_Byte (Natural (Height)),
         Descriptor_Arithmetic.Encode_Image
           (Local_Palette.Present,
            Interlaced,
            (if Local_Palette.Present then Local_Palette.Sorted else False),
            Code)];
   end Image_Descriptor;

   function Graphic_Control
     (Control : Frames.Graphic_Control) return Graphic_Control_Data
   is
     [Wire_Format.Extension_Introducer, Wire_Format.Graphic_Control_Label, 4,
      Extension_Arithmetic.Encode_Graphic_Control (Control),
      Extension_Arithmetic.Low_Byte (Natural (Control.Delay_CS)),
      Extension_Arithmetic.High_Byte (Natural (Control.Delay_CS)),
      (if Control.Has_Transparency then Byte (Control.Transparent_Index) else 0),
      Wire_Format.Block_Terminator];

   function Palette_Data
     (Palette : Palettes.Palette) return Streams.Byte_Array
   is
      Length : constant Natural := Encoded_Length (Palette_Length (Palette.Length));
      Data : Streams.Byte_Array (1 .. Length * 3) := [others => 0];
   begin
      for I in 0 .. Palette.Length - 1 loop
         Data (I * 3 + 1) := Palette.Colors (Palette_Index (I)).Red;
         Data (I * 3 + 2) := Palette.Colors (Palette_Index (I)).Green;
         Data (I * 3 + 3) := Palette.Colors (Palette_Index (I)).Blue;
      end loop;
      return Data;
   end Palette_Data;
end Giflib.Internal.Container_Writer;
