with Giflib.Errors;
with Giflib.Internal.Descriptor_Arithmetic;
with Giflib.Internal.Extension_Arithmetic;
with Giflib.Internal.Geometry_Arithmetic;
with Giflib.Internal.Bytes;

package body Giflib.Internal.Container is
   use type Streams.Byte_Array;

   function Truncated
     (Outcome : Results.Result;
      Object : Streams.Source'Class;
      Block : Block_Kind) return Results.Result
   is
      use type Errors.Error_Code;
   begin
      if Outcome.First_Error.Code = Errors.Source_Unexpected_End then
         return Results.Failure
           (Errors.Make
              (Errors.Truncated_Block,
               (Has_Source => Streams.Position (Object).Available,
                Source => Streams.Position (Object).Value,
                Block => Block,
                Expected => Outcome.First_Error.Context.Expected,
                Actual => Outcome.First_Error.Context.Actual,
                others => <>)));
      end if;
      return Outcome;
   end Truncated;

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
               (Has_Source => Streams.Position (Object, 6).Available,
                Source => Streams.Position (Object, 6).Value,
                Block => Header_Block,
                others => <>)));
      elsif Signature (4 .. 6) = [Character'Pos ('8'), Character'Pos ('7'), Character'Pos ('a')] then
         Header.Version := GIF87a;
      elsif Signature (4 .. 6) = [Character'Pos ('8'), Character'Pos ('9'), Character'Pos ('a')] then
         Header.Version := GIF89a;
      else
         return Results.Failure
           (Errors.Make
              (Errors.Invalid_Version,
               (Has_Source => Streams.Position (Object, 3).Available,
                Source => Streams.Position (Object, 3).Value,
                Block => Header_Block,
                others => <>)));
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
               (Has_Source => Streams.Position (Object, 7).Available,
                Source => Streams.Position (Object, 7).Value,
                Block => Logical_Screen_Descriptor_Block,
                Expected => 1,
                Actual => Byte_Count (Natural'Min (Natural (Width_Value), Natural (Height_Value))),
                others => <>)));
      elsif Width_Value > Natural (Constraints.Max_Logical_Width) then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Has_Source => Streams.Position (Object, 7).Available,
                Source => Streams.Position (Object, 7).Value,
                Block => Logical_Screen_Descriptor_Block,
                Expected => Byte_Count (Constraints.Max_Logical_Width),
                Actual => Byte_Count (Width_Value),
                Limit => Logical_Width_Limit,
                others => <>)));
      elsif Height_Value > Natural (Constraints.Max_Logical_Height) then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Has_Source => Streams.Position (Object, 5).Available,
                Source => Streams.Position (Object, 5).Value,
                Block => Logical_Screen_Descriptor_Block,
                Expected => Byte_Count (Constraints.Max_Logical_Height),
                Actual => Byte_Count (Height_Value),
                Limit => Logical_Height_Limit,
                others => <>)));
      end if;

      Header.Width := Image_Width (Width_Value);
      Header.Height := Image_Height (Height_Value);
      Packed_Fields := Descriptor_Arithmetic.Decode_Logical_Screen (Descriptor (5));
      Header.Has_Global_Palette := Packed_Fields.Has_Global_Palette;
      Header.Color_Resolution := Packed_Fields.Color_Resolution;
      Header.Global_Palette_Sorted := Packed_Fields.Global_Palette_Sorted;
      Header.Background_Index := Palette_Index (Descriptor (6));
      Header.Pixel_Aspect_Ratio := Descriptor (7);

      if Header.Has_Global_Palette then
         Palette_Length := Packed_Fields.Palette_Length;
         Header.Global_Palette.Length := Palette_Length;
         declare
            Raw : Streams.Byte_Array (1 .. Palette_Length * 3);
         begin
            Outcome := Streams.Read_Exact (Object, Raw);
            if not Results.Succeeded (Outcome) then
               return Truncated (Outcome, Object, Global_Color_Table_Block);
            end if;
            for I in 0 .. Palette_Length - 1 loop
               Header.Global_Palette.Colors (Palette_Index (I)) :=
                 (Red => Raw (Raw'First + I * 3),
                  Green => Raw (Raw'First + I * 3 + 1),
                  Blue => Raw (Raw'First + I * 3 + 2));
            end loop;
         end;
         if not Palettes.Contains (Header.Global_Palette, Header.Background_Index) then
            return Results.Failure
              (Errors.Make
                 (Errors.Palette_Index_Out_Of_Range,
                  (Has_Source => Streams.Position
                     (Object, Source_Offset (Palette_Length * 3)).Available,
                   Source => Streams.Position
                     (Object, Source_Offset (Palette_Length * 3)).Value,
                   Block => Logical_Screen_Descriptor_Block,
                   Expected => Byte_Count (Palette_Length - 1),
                   Actual => Byte_Count (Header.Background_Index),
                   others => <>)));
         end if;
      end if;
      return Results.Success;
   end Read_Header;

   function Read_Trailer (Object : in out Streams.Source'Class) return Results.Result is
      Value : Byte;
      Outcome : Results.Result;
   begin
      Outcome := Bytes.Read_Byte (Object, Value, Trailer_Block);
      if not Results.Succeeded (Outcome) then
         return Truncated (Outcome, Object, Trailer_Block);
      elsif Value /= 16#3B# then
         return Results.Failure
           (Errors.Make
              (Errors.Invalid_Block,
               (Has_Source => Streams.Position (Object, 1).Available,
                Source => Streams.Position (Object, 1).Value,
                Block => Trailer_Block,
                Expected => 16#3B#,
                Actual => Byte_Count (Value),
                others => <>)));
      end if;
      return Results.Success;
   end Read_Trailer;

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
   begin
      Descriptor := (others => <>);
      Effective_Palette := (others => <>);
      if Separator_Already_Read then
         Raw (1) := 16#2C#;
         Outcome := Streams.Read_Exact (Object, Raw (2 .. Raw'Last));
      else
         Outcome := Streams.Read_Exact (Object, Raw);
      end if;
      if not Results.Succeeded (Outcome) then
         return Truncated (Outcome, Object, Image_Descriptor_Block);
      elsif Raw (1) /= 16#2C# then
         return Results.Failure
           (Errors.Make
              (Errors.Invalid_Block,
               (Has_Source => Streams.Position (Object, 10).Available,
                Source => Streams.Position (Object, 10).Value,
                Block => Image_Descriptor_Block,
                Expected => 16#2C#,
                Actual => Byte_Count (Raw (1)),
                others => <>)));
      end if;

      Left_Value := Extension_Arithmetic.Decode_U16_LE (Raw (2), Raw (3));
      Top_Value := Extension_Arithmetic.Decode_U16_LE (Raw (4), Raw (5));
      Width_Value := Extension_Arithmetic.Decode_U16_LE (Raw (6), Raw (7));
      Height_Value := Extension_Arithmetic.Decode_U16_LE (Raw (8), Raw (9));
      Packed_Fields := Descriptor_Arithmetic.Decode_Image (Raw (10));
      Descriptor.Reserved_Bits := Packed_Fields.Reserved_Bits;
      declare
         Position : constant Streams.Source_Position_Result :=
           Streams.Position (Object, 1);
      begin
         Descriptor.Has_Packed_Field_Offset := Position.Available;
         Descriptor.Packed_Field_Offset := Position.Value;
      end;

      if Width_Value = 0 or else Height_Value = 0 then
         return Results.Failure
           (Errors.Make
              (Errors.Invalid_Dimensions,
               (Has_Source => Streams.Position (Object, 5).Available,
                Source => Streams.Position (Object, 5).Value,
                Block => Image_Descriptor_Block,
                Expected => 1,
                Actual => Byte_Count (Natural'Min (Natural (Width_Value), Natural (Height_Value))),
                others => <>)));
      elsif Packed_Fields.Reserved_Bits /= 0 and then Strictness = Strict then
         return Results.Failure
           (Errors.Make
              (Errors.Invalid_Block,
               (Has_Source => Descriptor.Has_Packed_Field_Offset,
                Source => Descriptor.Packed_Field_Offset,
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
               (Has_Source => Streams.Position (Object, 9).Available,
                Source => Streams.Position (Object, 9).Value,
                Block => Image_Descriptor_Block,
                Expected => Geometry_Arithmetic.Area (Header.Width, Header.Height),
                Actual => Geometry.Bounding_Area,
                others => <>)));
      end if;

      if Geometry.Pixel_Area > Byte_Count (Constraints.Max_Frame_Pixels) then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Has_Source => Streams.Position (Object, 5).Available,
                Source => Streams.Position (Object, 5).Value,
                Block => Image_Descriptor_Block,
                Expected => Byte_Count (Constraints.Max_Frame_Pixels),
                Actual => Geometry.Pixel_Area,
                Limit => Frame_Pixel_Limit,
                others => <>)));
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
         Descriptor.Local_Palette.Length := Palette_Length;
         declare
            Palette_Bytes : Streams.Byte_Array (1 .. Palette_Length * 3);
         begin
            Outcome := Streams.Read_Exact (Object, Palette_Bytes);
            if not Results.Succeeded (Outcome) then
               return Truncated (Outcome, Object, Local_Color_Table_Block);
            end if;
            for I in 0 .. Palette_Length - 1 loop
               Descriptor.Local_Palette.Colors (Palette_Index (I)) :=
                 (Red => Palette_Bytes (Palette_Bytes'First + I * 3),
                  Green => Palette_Bytes (Palette_Bytes'First + I * 3 + 1),
                  Blue => Palette_Bytes (Palette_Bytes'First + I * 3 + 2));
            end loop;
         end;
         Effective_Palette := Descriptor.Local_Palette;
      elsif Header.Has_Global_Palette then
         Effective_Palette := Header.Global_Palette;
      else
         return Results.Failure
           (Errors.Make
              (Errors.Missing_Color_Table,
               (Has_Source => Streams.Position (Object).Available,
                Source => Streams.Position (Object).Value,
                Block => Image_Descriptor_Block,
                others => <>)));
      end if;

      return Results.Success;
   end Read_Image_Descriptor;
end Giflib.Internal.Container;
