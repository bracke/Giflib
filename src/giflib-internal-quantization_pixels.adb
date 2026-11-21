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
   begin
      if X >= Natural (Source.Width)
        or else Y >= Natural (Source.Height)
        or else Source.Accessible_Bytes > Byte_Count (Source.Data'Length)
        or else (Y > 0
                 and then Byte_Count (Source.Stride) >
                   Byte_Count'Last / Byte_Count (Y))
      then
         return (Valid => False);
      end if;
      Row_Offset := Byte_Count (Y) * Byte_Count (Source.Stride);
      Column_Offset := Byte_Count (X) * Byte_Count (BPP);
      if Column_Offset > Byte_Count'Last - Row_Offset then
         return (Valid => False);
      end if;
      Offset := Row_Offset + Column_Offset;
      if Source.Accessible_Bytes < Byte_Count (BPP)
        or else Offset > Source.Accessible_Bytes - Byte_Count (BPP)
        or else Offset > Byte_Count (Source.Data'Length) - Byte_Count (BPP)
      then
         return (Valid => False);
      end if;
      Position := Source.Data'First + Natural (Offset);
      return (Valid => True, Value => Read_Validated (Source, Position));
   end Read_Pixel;

   function Row_Start
     (Source : Images.Image_View;
      Y : Natural) return Positive
   is
      Offset : constant Byte_Count :=
        Byte_Count (Y) * Byte_Count (Source.Stride);
   begin
      return Source.Data'First + Natural (Offset);
   end Row_Start;

   function Read_Validated
     (Source : Images.Image_View;
      Position : Positive) return Source_Pixel
   is
   begin
      return
        (case Source.Format is
           when Indexed_8 => Read_Indexed_8_Validated (Source, Position),
           when RGB_24 => Read_RGB_24_Validated (Source, Position),
           when BGR_24 => Read_BGR_24_Validated (Source, Position),
           when RGBA_32 => Read_RGBA_32_Validated (Source, Position),
           when BGRA_32 => Read_BGRA_32_Validated (Source, Position));
   end Read_Validated;

   function Read_Indexed_8_Validated
     (Source : Images.Image_View;
      Position : Positive) return Source_Pixel
   is
      pragma Unreferenced (Source, Position);
   begin
      return (Color => (others => 0), Alpha => 255);
   end Read_Indexed_8_Validated;

   function Read_RGB_24_Validated
     (Source : Images.Image_View;
      Position : Positive) return Source_Pixel is
     ((Color =>
         (Source.Data (Position), Source.Data (Position + 1),
          Source.Data (Position + 2)),
       Alpha => 255));

   function Read_BGR_24_Validated
     (Source : Images.Image_View;
      Position : Positive) return Source_Pixel is
     ((Color =>
         (Source.Data (Position + 2), Source.Data (Position + 1),
          Source.Data (Position)),
       Alpha => 255));

   function Read_RGBA_32_Validated
     (Source : Images.Image_View;
      Position : Positive) return Source_Pixel is
     ((Color =>
         (Source.Data (Position), Source.Data (Position + 1),
          Source.Data (Position + 2)),
       Alpha => Source.Data (Position + 3)));

   function Read_BGRA_32_Validated
     (Source : Images.Image_View;
      Position : Positive) return Source_Pixel is
     ((Color =>
         (Source.Data (Position + 2), Source.Data (Position + 1),
          Source.Data (Position)),
       Alpha => Source.Data (Position + 3)));

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
