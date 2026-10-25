with Giflib.Animations;
with Giflib.Errors;
with Giflib.Limits;
with Giflib.Palettes;
with Giflib.Results;
with Giflib.Streams;

package Giflib.Internal.Container is
   pragma Preelaborate;

   subtype Header_Info is Animations.Screen_Info;

   type Image_Descriptor is record
      Left : Coordinate := 0;
      Top : Coordinate := 0;
      Width : Image_Width := Image_Width'First;
      Height : Image_Height := Image_Height'First;
      Has_Local_Palette : Boolean := False;
      Interlaced : Boolean := False;
      Local_Palette_Sorted : Boolean := False;
      Reserved_Bits : Byte := 0;
      Packed_Field_Position : Errors.Source_Position_Context;
   end record;

   function Read_Header
     (Object : in out Streams.Source'Class;
      Constraints : Limits.Limit_Set;
      Header : out Header_Info) return Results.Result;

   function Read_Image_Descriptor
     (Object : in out Streams.Source'Class;
      Header : Header_Info;
      Constraints : Limits.Limit_Set;
      Descriptor : out Image_Descriptor;
      Effective_Palette : out Palettes.Palette;
      Strictness : Strictness_Mode := Strict;
      Separator_Already_Read : Boolean := False) return Results.Result;
end Giflib.Internal.Container;
