separate (Giflib.Internal.Container)
function Read_Image_Descriptor
  (Object : in out Streams.Source'Class;
   Header : Header_Info;
   Constraints : Limits.Limit_Set;
   Descriptor : out Image_Descriptor;
   Effective_Palette : out Palettes.Palette;
   Strictness : Strictness_Mode := Strict;
   Separator_Already_Read : Boolean := False) return Results.Result
is
   Raw : Streams.Byte_Array (1 .. 10);
   Outcome : Results.Result;
   Left_Value : Extension_Arithmetic.Unsigned_16_Value;
   Top_Value : Extension_Arithmetic.Unsigned_16_Value;
   Width_Value : Extension_Arithmetic.Unsigned_16_Value;
   Height_Value : Extension_Arithmetic.Unsigned_16_Value;
   Packed_Fields : Descriptor_Arithmetic.Image_Fields;
   Palette_Length : Natural;
   Geometry : Geometry_Arithmetic.Rectangle_Analysis;
   Descriptor_End : Streams.Source_Position_Result;
begin
   Descriptor := (others => <>);
   Effective_Palette := (others => <>);
   if Separator_Already_Read then
      Raw (1) := Wire_Format.Image_Separator;
      Outcome := Streams.Read_Exact (Object, Raw (2 .. Raw'Last));
   else
      Outcome := Streams.Read_Exact (Object, Raw);
   end if;
   if not Results.Succeeded (Outcome) then
      return Truncated (Outcome, Object, Image_Descriptor_Block);
   elsif Raw (1) /= Wire_Format.Image_Separator then
      return Results.Failure
        (Errors.Make
           (Errors.Invalid_Block,
            Diagnostics.At_Source
              (Object,
               (Block => Image_Descriptor_Block,
                Expected => Byte_Count (Wire_Format.Image_Separator),
                Actual => Byte_Count (Raw (1)),
                others => <>),
               10)));
   end if;

   Left_Value := Extension_Arithmetic.Decode_U16_LE (Raw (2), Raw (3));
   Top_Value := Extension_Arithmetic.Decode_U16_LE (Raw (4), Raw (5));
   Width_Value := Extension_Arithmetic.Decode_U16_LE (Raw (6), Raw (7));
   Height_Value := Extension_Arithmetic.Decode_U16_LE (Raw (8), Raw (9));
   Packed_Fields := Descriptor_Arithmetic.Decode_Image (Raw (10));
   Descriptor.Reserved_Bits := Packed_Fields.Reserved_Bits;
   Descriptor_End := Streams.Position (Object);
   declare
      Position : constant Streams.Source_Position_Result :=
        Diagnostics.Rewind (Descriptor_End, 1);
   begin
      Descriptor.Packed_Field_Position :=
        (if Position.Available
         then Errors.Source_Position_At (Position.Value)
         else (State => Errors.Position_Unavailable));
   end;

   if Width_Value = 0 or else Height_Value = 0 then
      return Results.Failure
        (Errors.Make
           (Errors.Invalid_Dimensions,
            Diagnostics.With_Source
              ((Block => Image_Descriptor_Block,
                Expected => 1,
                Actual => Byte_Count
                  (Natural'Min (Natural (Width_Value), Natural (Height_Value))),
                others => <>),
               Diagnostics.Rewind (Descriptor_End, 5))));
   elsif Packed_Fields.Reserved_Bits /= 0 and then Strictness = Strict then
      return Results.Failure
        (Errors.Make
           (Errors.Invalid_Block,
            (Source_Position => Descriptor.Packed_Field_Position,
             Block => Image_Descriptor_Block,
             Expected => 0,
             Actual => Byte_Count (Packed_Fields.Reserved_Bits),
             others => <>)));
   end if;

   Geometry := Geometry_Arithmetic.Analyze_Rectangle
     (Coordinate (Left_Value),
      Coordinate (Top_Value),
      Image_Width (Width_Value),
      Image_Height (Height_Value),
      Header.Width,
      Header.Height);
   if not Geometry.Fits then
      return Results.Failure
        (Errors.Make
           (Errors.Frame_Out_Of_Bounds,
            Diagnostics.With_Source
              ((Block => Image_Descriptor_Block,
                Expected => Geometry_Arithmetic.Area
                  (Header.Width, Header.Height),
                Actual => Geometry.Bounding_Area,
                others => <>),
               Diagnostics.Rewind (Descriptor_End, 9))));
   end if;

   if Geometry.Pixel_Area > Byte_Count (Constraints.Max_Frame_Pixels) then
      return Results.Failure
        (Errors.Make
           (Errors.Limit_Exceeded,
            Diagnostics.With_Source
              ((Block => Image_Descriptor_Block,
                Expected => Byte_Count (Constraints.Max_Frame_Pixels),
                Actual => Geometry.Pixel_Area,
                Limit => Frame_Pixel_Limit,
                others => <>),
               Diagnostics.Rewind (Descriptor_End, 5))));
   end if;

   Descriptor.Left := Coordinate (Left_Value);
   Descriptor.Top := Coordinate (Top_Value);
   Descriptor.Width := Image_Width (Width_Value);
   Descriptor.Height := Image_Height (Height_Value);
   Descriptor.Has_Local_Palette := Packed_Fields.Has_Local_Palette;
   Descriptor.Interlaced := Packed_Fields.Interlaced;
   Descriptor.Local_Palette_Sorted := Packed_Fields.Local_Palette_Sorted;

   if Descriptor.Has_Local_Palette then
      Palette_Length := Packed_Fields.Palette_Length;
      Outcome := Read_Color_Table
        (Object, Palette_Length, Local_Color_Table_Block,
         Effective_Palette);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
   elsif Header.Has_Global_Palette then
      Effective_Palette := Header.Global_Palette;
   else
      return Results.Failure
        (Errors.Make
           (Errors.Missing_Color_Table,
            Diagnostics.With_Source
              ((Block => Image_Descriptor_Block, others => <>),
               Descriptor_End)));
   end if;

   return Results.Success;
end Read_Image_Descriptor;
