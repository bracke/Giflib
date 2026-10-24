with Giflib.Limits;
with Giflib.Palettes;
with Giflib.Results;
with Giflib.Streams;

package Giflib.Internal.Container is
   pragma Preelaborate;

   type Header_Info is record
      Version : GIF_Version := GIF89a;
      Width : Image_Width := Image_Width'First;
      Height : Image_Height := Image_Height'First;
      Has_Global_Palette : Boolean := False;
      Global_Palette : Palettes.Palette;
      Color_Resolution : Positive range 1 .. 8 := 1;
      Global_Palette_Sorted : Boolean := False;
      Background_Index : Palette_Index := 0;
      Pixel_Aspect_Ratio : Byte := 0;
   end record;

   type Image_Descriptor is record
      Left : Coordinate := 0;
      Top : Coordinate := 0;
      Width : Image_Width := Image_Width'First;
      Height : Image_Height := Image_Height'First;
      Has_Local_Palette : Boolean := False;
      Local_Palette : Palettes.Palette;
      Interlaced : Boolean := False;
      Local_Palette_Sorted : Boolean := False;
   end record;

   function Read_Header
     (Object : in out Streams.Source'Class;
      Constraints : Limits.Limit_Set;
      Header : out Header_Info) return Results.Result;

   function Read_Trailer (Object : in out Streams.Source'Class) return Results.Result;

   function Read_Image_Descriptor
     (Object : in out Streams.Source'Class;
      Header : Header_Info;
      Constraints : Limits.Limit_Set;
      Descriptor : out Image_Descriptor;
      Effective_Palette : out Palettes.Palette;
      Separator_Already_Read : Boolean := False) return Results.Result;
end Giflib.Internal.Container;
