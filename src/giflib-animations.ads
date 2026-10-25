with Giflib.Palettes;

package Giflib.Animations is
   pragma Pure;

   type Loop_State is (No_Loop_Extension, Finite_Loop_Count, Infinite_Looping);

   type Loop_Info (State : Loop_State := No_Loop_Extension) is record
      case State is
         when Finite_Loop_Count =>
            Count : Positive range 1 .. 65_535 := 1;
         when No_Loop_Extension | Infinite_Looping =>
            null;
      end case;
   end record;

   function Raw_Count (Info : Loop_Info) return Natural is
     (case Info.State is
         when No_Loop_Extension | Infinite_Looping => 0,
         when Finite_Loop_Count => Info.Count);

   No_Loop : constant Loop_Info := (State => No_Loop_Extension);

   type Screen_Info (Has_Global_Palette : Boolean := False) is record
      Version : GIF_Version := GIF89a;
      Width : Image_Width := Image_Width'First;
      Height : Image_Height := Image_Height'First;
      Color_Resolution : Positive range 1 .. 8 := 1;
      Background_Index : Palette_Index := 0;
      Pixel_Aspect_Ratio : Byte := 0;
      case Has_Global_Palette is
         when True =>
            Global_Palette : Palettes.Palette;
            Global_Palette_Sorted : Boolean := False;
         when False =>
            null;
      end case;
   end record;
end Giflib.Animations;
