package body Giflib.Internal.Quantization_Arithmetic with SPARK_Mode is
   function Histogram_Of (Color : Palettes.RGB_Color) return Histogram_Index is
   begin
      return
        Natural (Color.Red) / 8 * 1_024
          + Natural (Color.Green) / 8 * 32
          + Natural (Color.Blue) / 8;
   end Histogram_Of;

   function Red_Bucket (Index : Histogram_Index) return Color_Bucket is
     (Index / 1_024);

   function Green_Bucket (Index : Histogram_Index) return Color_Bucket is
     (Index / 32 mod 32);

   function Blue_Bucket (Index : Histogram_Index) return Color_Bucket is
     (Index mod 32);

   function Clamp (Value : Long_Integer) return Byte is
     (if Value < 0 then 0 elsif Value > 255 then 255 else Byte (Value));

   function Difference (Left, Right : Byte) return Channel_Difference is
     (if Left >= Right
      then Natural (Left - Right)
      else Natural (Right - Left));

   function Squared_Distance
     (Left : Palettes.RGB_Color;
      Right : Palettes.RGB_Color) return Color_Distance
   is
      DR : constant Channel_Difference := Difference (Left.Red, Right.Red);
      DG : constant Channel_Difference := Difference (Left.Green, Right.Green);
      DB : constant Channel_Difference := Difference (Left.Blue, Right.Blue);
   begin
      return DR * DR + DG * DG + DB * DB;
   end Squared_Distance;
end Giflib.Internal.Quantization_Arithmetic;
