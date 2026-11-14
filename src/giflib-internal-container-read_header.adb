separate (Giflib.Internal.Container)
function Read_Header
  (Object : in out Streams.Source'Class;
   Constraints : Limits.Limit_Set;
   Header : out Header_Info) return Results.Result
is
   Signature : Streams.Byte_Array (1 .. 6);
   Descriptor : Streams.Byte_Array (1 .. 7);
   Outcome : Results.Result;
   Width_Value : Extension_Arithmetic.Unsigned_16_Value;
   Height_Value : Extension_Arithmetic.Unsigned_16_Value;
   Packed_Fields : Descriptor_Arithmetic.Logical_Screen_Fields;
   Palette_Length : Natural;
   Version : GIF_Version := GIF89a;
begin
   Header := (others => <>);
   Outcome := Streams.Read_Exact (Object, Signature);
   if not Results.Succeeded (Outcome) then
      return Truncated (Outcome, Object, Header_Block);
   end if;

   if Signature (1 .. 3) /= [Character'Pos ('G'), Character'Pos ('I'), Character'Pos ('F')] then
      return Results.Failure
        (Errors.Make
           (Errors.Invalid_Signature,
            Diagnostics.At_Source
              (Object, (Block => Header_Block, others => <>), 6)));
   elsif Signature (4 .. 6) = [Character'Pos ('8'), Character'Pos ('7'), Character'Pos ('a')] then
      Version := GIF87a;
   elsif Signature (4 .. 6) = [Character'Pos ('8'), Character'Pos ('9'), Character'Pos ('a')] then
      Version := GIF89a;
   else
      return Results.Failure
        (Errors.Make
           (Errors.Invalid_Version,
            Diagnostics.At_Source
              (Object, (Block => Header_Block, others => <>), 3)));
   end if;

   Outcome := Streams.Read_Exact (Object, Descriptor);
   if not Results.Succeeded (Outcome) then
      return Truncated (Outcome, Object, Logical_Screen_Descriptor_Block);
   end if;

   Width_Value := Extension_Arithmetic.Decode_U16_LE (Descriptor (1), Descriptor (2));
   Height_Value := Extension_Arithmetic.Decode_U16_LE (Descriptor (3), Descriptor (4));
   if Width_Value = 0 or else Height_Value = 0 then
      return Results.Failure
        (Errors.Make
           (Errors.Invalid_Dimensions,
            Diagnostics.At_Source
              (Object,
               (Block => Logical_Screen_Descriptor_Block,
                Expected => 1,
                Actual => Byte_Count
                  (Natural'Min (Natural (Width_Value), Natural (Height_Value))),
                others => <>),
               7)));
   elsif Width_Value > Natural (Constraints.Max_Logical_Width) then
      return Results.Failure
        (Errors.Make
           (Errors.Limit_Exceeded,
            Diagnostics.At_Source
              (Object,
               (Block => Logical_Screen_Descriptor_Block,
                Expected => Byte_Count (Constraints.Max_Logical_Width),
                Actual => Byte_Count (Width_Value),
                Limit => Logical_Width_Limit,
                others => <>),
               7)));
   elsif Height_Value > Natural (Constraints.Max_Logical_Height) then
      return Results.Failure
        (Errors.Make
           (Errors.Limit_Exceeded,
            Diagnostics.At_Source
              (Object,
               (Block => Logical_Screen_Descriptor_Block,
                Expected => Byte_Count (Constraints.Max_Logical_Height),
                Actual => Byte_Count (Height_Value),
                Limit => Logical_Height_Limit,
                others => <>),
               5)));
   end if;

   Packed_Fields := Descriptor_Arithmetic.Decode_Logical_Screen (Descriptor (5));
   if Packed_Fields.Has_Global_Palette then
      Header :=
        (Has_Global_Palette => True,
         Version => Version,
         Width => Image_Width (Width_Value),
         Height => Image_Height (Height_Value),
         Color_Resolution => Packed_Fields.Color_Resolution,
         Background_Index => Palette_Index (Descriptor (6)),
         Pixel_Aspect_Ratio => Descriptor (7),
         Global_Palette => (others => <>),
         Global_Palette_Sorted => Packed_Fields.Global_Palette_Sorted);
   else
      Header :=
        (Has_Global_Palette => False,
         Version => Version,
         Width => Image_Width (Width_Value),
         Height => Image_Height (Height_Value),
         Color_Resolution => Packed_Fields.Color_Resolution,
         Background_Index => Palette_Index (Descriptor (6)),
         Pixel_Aspect_Ratio => Descriptor (7));
   end if;

   if Header.Has_Global_Palette then
      Palette_Length := Packed_Fields.Palette_Length;
      Outcome := Read_Color_Table
        (Object, Palette_Length, Global_Color_Table_Block,
         Header.Global_Palette);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      if not Palettes.Contains (Header.Global_Palette, Header.Background_Index) then
         return Results.Failure
           (Errors.Make
              (Errors.Palette_Index_Out_Of_Range,
               Diagnostics.At_Source
                 (Object,
                  (Block => Logical_Screen_Descriptor_Block,
                   Expected => Byte_Count (Palette_Length - 1),
                   Actual => Byte_Count (Header.Background_Index),
                   others => <>),
                  Source_Offset (Palette_Length * 3))));
      end if;
   end if;
   return Results.Success;
end Read_Header;
