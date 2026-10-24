with Interfaces;

package body Giflib.Internal.Quantization_Pixels is
   use type Interfaces.Unsigned_32;

   function Pixel_At
     (Source : Images.Image_View;
      X, Y   : Natural) return Source_Pixel
   is
      BPP : constant Natural := Images.Bytes_Per_Pixel (Source.Format);
      Offset : constant Byte_Count :=
        Byte_Count (Y) * Byte_Count (Source.Stride) + Byte_Count (X * BPP);
      Position : constant Positive := Source.Data'First + Natural (Offset);
      Result : Source_Pixel;
   begin
      case Source.Format is
         when RGB_24 =>
            Result.Color :=
              (Source.Data (Position), Source.Data (Position + 1),
               Source.Data (Position + 2));
         when BGR_24 =>
            Result.Color :=
              (Source.Data (Position + 2), Source.Data (Position + 1),
               Source.Data (Position));
         when RGBA_32 =>
            Result.Color :=
              (Source.Data (Position), Source.Data (Position + 1),
               Source.Data (Position + 2));
            Result.Alpha := Source.Data (Position + 3);
         when BGRA_32 =>
            Result.Color :=
              (Source.Data (Position + 2), Source.Data (Position + 1),
               Source.Data (Position));
            Result.Alpha := Source.Data (Position + 3);
         when Indexed_8 =>
            null;
      end case;
      return Result;
   end Pixel_At;

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

   function Cache_Start (Key, Cache_Size : Natural) return Natural is
      Mixed : Interfaces.Unsigned_32 := Interfaces.Unsigned_32 (Key);
   begin
      Mixed := Mixed xor Interfaces.Shift_Right (Mixed, 12);
      Mixed := Mixed * 16#9E37_79B1#;
      Mixed := Mixed xor Interfaces.Shift_Right (Mixed, 16);
      return Natural (Mixed mod Interfaces.Unsigned_32 (Cache_Size));
   end Cache_Start;
end Giflib.Internal.Quantization_Pixels;
