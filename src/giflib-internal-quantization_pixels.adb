package body Giflib.Internal.Quantization_Pixels is
   function Read_Pixel
     (Source : Images.Image_View;
      X, Y   : Natural) return Pixel_Result
   is
      BPP : constant Natural := Images.Bytes_Per_Pixel (Source.Format);
      Row_Offset : Byte_Count;
      Column_Offset : Byte_Count;
      Offset : Byte_Count;
      Position : Positive;
      Result : Pixel_Result;
   begin
      if X >= Natural (Source.Width)
        or else Y >= Natural (Source.Height)
        or else Source.Accessible_Bytes > Byte_Count (Source.Data'Length)
        or else (Y > 0
                 and then Byte_Count (Source.Stride) >
                   Byte_Count'Last / Byte_Count (Y))
      then
         return Result;
      end if;
      Row_Offset := Byte_Count (Y) * Byte_Count (Source.Stride);
      Column_Offset := Byte_Count (X) * Byte_Count (BPP);
      if Column_Offset > Byte_Count'Last - Row_Offset then
         return Result;
      end if;
      Offset := Row_Offset + Column_Offset;
      if Source.Accessible_Bytes < Byte_Count (BPP)
        or else Offset > Source.Accessible_Bytes - Byte_Count (BPP)
        or else Offset > Byte_Count (Source.Data'Length) - Byte_Count (BPP)
      then
         return Result;
      end if;
      Position := Source.Data'First + Natural (Offset);
      case Source.Format is
         when RGB_24 =>
            Result.Value.Color :=
              (Source.Data (Position), Source.Data (Position + 1),
               Source.Data (Position + 2));
         when BGR_24 =>
            Result.Value.Color :=
              (Source.Data (Position + 2), Source.Data (Position + 1),
               Source.Data (Position));
         when RGBA_32 =>
            Result.Value.Color :=
              (Source.Data (Position), Source.Data (Position + 1),
               Source.Data (Position + 2));
            Result.Value.Alpha := Source.Data (Position + 3);
         when BGRA_32 =>
            Result.Value.Color :=
              (Source.Data (Position + 2), Source.Data (Position + 1),
               Source.Data (Position));
            Result.Value.Alpha := Source.Data (Position + 3);
         when Indexed_8 =>
            null;
      end case;
      Result.Valid := True;
      return Result;
   end Read_Pixel;

   function Is_Transparent
     (Pixel            : Source_Pixel;
      Source_Format    : Pixel_Format;
      Use_Transparency : Boolean;
      Alpha_Threshold  : Byte) return Boolean
   is
     (Use_Transparency
      and then Source_Format in RGBA_32 | BGRA_32
      and then Pixel.Alpha <= Alpha_Threshold);

   function Color_Key (Color : Palettes.RGB_Color) return Natural is
     (Natural (Color.Red) * 65_536
      + Natural (Color.Green) * 256
      + Natural (Color.Blue));

end Giflib.Internal.Quantization_Pixels;
