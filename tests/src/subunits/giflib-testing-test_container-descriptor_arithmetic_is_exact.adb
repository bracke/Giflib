separate (Giflib.Testing.Test_Container)
procedure Descriptor_Arithmetic_Is_Exact (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   package Arithmetic renames Giflib.Internal.Descriptor_Arithmetic;
begin
   for Resolution in Arithmetic.Color_Resolution loop
      for Has_Palette in Boolean loop
         for Sorted in Boolean loop
            for Size in Arithmetic.Palette_Size_Code loop
               declare
                  Packed : constant Giflib.Byte :=
                    Arithmetic.Encode_Logical_Screen
                      (Resolution, Has_Palette, Sorted, Size);
                  Fields : constant Arithmetic.Logical_Screen_Fields :=
                    Arithmetic.Decode_Logical_Screen (Packed);
               begin
                  Assert
                    (Fields.Has_Global_Palette = Has_Palette
                     and then Fields.Color_Resolution = Resolution
                     and then Fields.Global_Palette_Sorted = Sorted
                     and then Fields.Palette_Length = 2 ** (Size + 1),
                     "logical-screen packed fields did not round trip");
               end;
            end loop;
         end loop;
      end loop;
   end loop;

   for Has_Palette in Boolean loop
      for Interlaced in Boolean loop
         for Sorted in Boolean loop
            for Size in Arithmetic.Palette_Size_Code loop
               declare
                  Packed : constant Giflib.Byte :=
                    Arithmetic.Encode_Image
                      (Has_Palette, Interlaced, Sorted, Size);
                  Fields : constant Arithmetic.Image_Fields :=
                    Arithmetic.Decode_Image (Packed);
               begin
                  Assert
                    (Fields.Has_Local_Palette = Has_Palette
                     and then Fields.Interlaced = Interlaced
                     and then Fields.Local_Palette_Sorted = Sorted
                     and then Fields.Reserved_Bits = 0
                     and then Fields.Palette_Length = 2 ** (Size + 1),
                     "image-descriptor packed fields did not round trip");
               end;
            end loop;
         end loop;
      end loop;
   end loop;

   for Packed in Giflib.Byte loop
      declare
         Screen : constant Arithmetic.Logical_Screen_Fields :=
           Arithmetic.Decode_Logical_Screen (Packed);
         Image : constant Arithmetic.Image_Fields :=
           Arithmetic.Decode_Image (Packed);
      begin
         Assert
           (Screen.Palette_Length = Image.Palette_Length
            and then Image.Reserved_Bits =
              Giflib.Byte (((Natural (Packed) / 8) mod 4) * 8),
            "packed palette-size bits were decoded inconsistently");
      end;
   end loop;
end Descriptor_Arithmetic_Is_Exact;
