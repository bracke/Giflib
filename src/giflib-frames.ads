with Giflib.Palettes;

package Giflib.Frames is
   pragma Pure;

   type Disposal_Method is range 0 .. 7;

   type Graphic_Control is record
      Disposal : Disposal_Method := 0;
      User_Input : Boolean := False;
      Delay_CS : Delay_Centiseconds := 0;
      Has_Transparency : Boolean := False;
      Transparent_Index : Palette_Index := 0;
   end record;

   Default_Control : constant Graphic_Control := (others => <>);

   type Rectangle is record
      Left : Coordinate := 0;
      Top : Coordinate := 0;
      Width : Image_Width := Image_Width'First;
      Height : Image_Height := Image_Height'First;
   end record;

   type Indexed_Frame_Info is record
      Ordinal : Frame_Ordinal := 0;
      Left : Coordinate := 0;
      Top : Coordinate := 0;
      Width : Image_Width := Image_Width'First;
      Height : Image_Height := Image_Height'First;
      Interlaced : Boolean := False;
      Has_Local_Palette : Boolean := False;
      Local_Palette_Sorted : Boolean := False;
      Effective_Palette : Palettes.Palette;
      Control : Graphic_Control := Default_Control;
   end record;

   type Rendered_Frame_Info is record
      Ordinal : Frame_Ordinal := 0;
      Canvas_Width : Image_Width := Image_Width'First;
      Canvas_Height : Image_Height := Image_Height'First;
      Source_Rectangle : Rectangle;
      Control : Graphic_Control := Default_Control;
   end record;
end Giflib.Frames;
