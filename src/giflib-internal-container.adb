with Interfaces;
with Giflib.Errors;
with Giflib.Internal.Bytes;

package body Giflib.Internal.Container is
   use type Interfaces.Unsigned_16;
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
               (Source => Object.Offset,
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
      Width_Value : Interfaces.Unsigned_16;
      Height_Value : Interfaces.Unsigned_16;
      Packed : Natural;
      Palette_Length : Natural;
   begin
      Header := (others => <>);
      Outcome := Streams.Read_Exact (Object, Signature);
      if not Results.Succeeded (Outcome) then
         return Truncated (Outcome, Object, Header_Block);
      end if;

      if Signature (1 .. 3) /= [Character'Pos ('G'), Character'Pos ('I'), Character'Pos ('F')] then
         return Results.Failure
           (Errors.Make (Errors.Invalid_Signature, (Source => Object.Offset - 6, Block => Header_Block, others => <>)));
      elsif Signature (4 .. 6) = [Character'Pos ('8'), Character'Pos ('7'), Character'Pos ('a')] then
         Header.Version := GIF87a;
      elsif Signature (4 .. 6) = [Character'Pos ('8'), Character'Pos ('9'), Character'Pos ('a')] then
         Header.Version := GIF89a;
      else
         return Results.Failure
           (Errors.Make (Errors.Invalid_Version, (Source => Object.Offset - 3, Block => Header_Block, others => <>)));
      end if;

      Outcome := Streams.Read_Exact (Object, Descriptor);
      if not Results.Succeeded (Outcome) then
         return Truncated (Outcome, Object, Logical_Screen_Descriptor_Block);
      end if;

      Width_Value := Interfaces.Unsigned_16 (Descriptor (1))
        or Interfaces.Shift_Left (Interfaces.Unsigned_16 (Descriptor (2)), 8);
      Height_Value := Interfaces.Unsigned_16 (Descriptor (3))
        or Interfaces.Shift_Left (Interfaces.Unsigned_16 (Descriptor (4)), 8);
      if Width_Value = 0 or else Height_Value = 0 then
         return Results.Failure
           (Errors.Make
              (Errors.Invalid_Dimensions,
               (Source => Object.Offset - 7,
                Block => Logical_Screen_Descriptor_Block,
                Expected => 1,
                Actual => Byte_Count (Natural'Min (Natural (Width_Value), Natural (Height_Value))),
                others => <>)));
      elsif Width_Value > Interfaces.Unsigned_16 (Constraints.Max_Logical_Width) then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Source => Object.Offset - 7,
                Block => Logical_Screen_Descriptor_Block,
                Expected => Byte_Count (Constraints.Max_Logical_Width),
                Actual => Byte_Count (Width_Value),
                Limit => Logical_Width_Limit,
                others => <>)));
      elsif Height_Value > Interfaces.Unsigned_16 (Constraints.Max_Logical_Height) then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Source => Object.Offset - 5,
                Block => Logical_Screen_Descriptor_Block,
                Expected => Byte_Count (Constraints.Max_Logical_Height),
                Actual => Byte_Count (Height_Value),
                Limit => Logical_Height_Limit,
                others => <>)));
      end if;

      Header.Width := Image_Width (Width_Value);
      Header.Height := Image_Height (Height_Value);
      Packed := Natural (Descriptor (5));
      Header.Has_Global_Palette := (Packed / 16#80#) mod 2 = 1;
      Header.Color_Resolution := ((Packed / 16#10#) mod 8) + 1;
      Header.Global_Palette_Sorted := (Packed / 16#08#) mod 2 = 1;
      Header.Background_Index := Palette_Index (Descriptor (6));
      Header.Pixel_Aspect_Ratio := Descriptor (7);

      if Header.Has_Global_Palette then
         Palette_Length := 2 ** ((Packed mod 8) + 1);
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
                  (Source => Object.Offset - Source_Offset (Palette_Length * 3),
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
               (Source => Object.Offset - 1,
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
      Separator_Already_Read : Boolean := False) return Results.Result
   is
      Raw : Streams.Byte_Array (1 .. 10);
      Outcome : Results.Result;
      Left_Value : Interfaces.Unsigned_16;
      Top_Value : Interfaces.Unsigned_16;
      Width_Value : Interfaces.Unsigned_16;
      Height_Value : Interfaces.Unsigned_16;
      Packed : Natural;
      Palette_Length : Natural;
      Right_Edge : Byte_Count;
      Bottom_Edge : Byte_Count;
      Pixels : Byte_Count;
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
               (Source => Object.Offset - 10,
                Block => Image_Descriptor_Block,
                Expected => 16#2C#,
                Actual => Byte_Count (Raw (1)),
                others => <>)));
      end if;

      Left_Value := Interfaces.Unsigned_16 (Raw (2))
        or Interfaces.Shift_Left (Interfaces.Unsigned_16 (Raw (3)), 8);
      Top_Value := Interfaces.Unsigned_16 (Raw (4))
        or Interfaces.Shift_Left (Interfaces.Unsigned_16 (Raw (5)), 8);
      Width_Value := Interfaces.Unsigned_16 (Raw (6))
        or Interfaces.Shift_Left (Interfaces.Unsigned_16 (Raw (7)), 8);
      Height_Value := Interfaces.Unsigned_16 (Raw (8))
        or Interfaces.Shift_Left (Interfaces.Unsigned_16 (Raw (9)), 8);

      if Width_Value = 0 or else Height_Value = 0 then
         return Results.Failure
           (Errors.Make
              (Errors.Invalid_Dimensions,
               (Source => Object.Offset - 5,
                Block => Image_Descriptor_Block,
                Expected => 1,
                Actual => Byte_Count (Natural'Min (Natural (Width_Value), Natural (Height_Value))),
                others => <>)));
      end if;

      Right_Edge := Byte_Count (Left_Value) + Byte_Count (Width_Value);
      Bottom_Edge := Byte_Count (Top_Value) + Byte_Count (Height_Value);
      if Right_Edge > Byte_Count (Header.Width) or else Bottom_Edge > Byte_Count (Header.Height) then
         return Results.Failure
           (Errors.Make
              (Errors.Frame_Out_Of_Bounds,
               (Source => Object.Offset - 9,
                Block => Image_Descriptor_Block,
                Expected => Byte_Count (Header.Width) * Byte_Count (Header.Height),
                Actual => Right_Edge * Bottom_Edge,
                others => <>)));
      end if;

      Pixels := Byte_Count (Width_Value) * Byte_Count (Height_Value);
      if Pixels > Byte_Count (Constraints.Max_Frame_Pixels) then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Source => Object.Offset - 5,
                Block => Image_Descriptor_Block,
                Expected => Byte_Count (Constraints.Max_Frame_Pixels),
                Actual => Pixels,
                Limit => Frame_Pixel_Limit,
                others => <>)));
      end if;

      Descriptor.Left := Coordinate (Left_Value);
      Descriptor.Top := Coordinate (Top_Value);
      Descriptor.Width := Image_Width (Width_Value);
      Descriptor.Height := Image_Height (Height_Value);
      Packed := Natural (Raw (10));
      Descriptor.Has_Local_Palette := (Packed / 16#80#) mod 2 = 1;
      Descriptor.Interlaced := (Packed / 16#40#) mod 2 = 1;
      Descriptor.Local_Palette_Sorted := (Packed / 16#20#) mod 2 = 1;

      if Descriptor.Has_Local_Palette then
         Palette_Length := 2 ** ((Packed mod 8) + 1);
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
               (Source => Object.Offset,
                Block => Image_Descriptor_Block,
                others => <>)));
      end if;

      return Results.Success;
   end Read_Image_Descriptor;
end Giflib.Internal.Container;
