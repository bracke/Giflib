with Giflib.Palettes;

package Giflib.Animations is
   pragma Pure;

   type Loop_State is (No_Loop_Extension, Finite_Loop_Count, Infinite_Looping);

   type Loop_Info is record
      State : Loop_State := No_Loop_Extension;
      Raw_Count : Natural range 0 .. 65_535 := 0;
   end record;

   No_Loop : constant Loop_Info := (others => <>);

   type Screen_Info is record
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
end Giflib.Animations;
