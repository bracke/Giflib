with Giflib.Palettes;

package Giflib.Internal.Quantization_Arithmetic with SPARK_Mode is
   pragma Pure;

   subtype Histogram_Index is Natural range 0 .. 32_767;
   subtype Color_Bucket is Natural range 0 .. 31;
   subtype Channel_Difference is Natural range 0 .. 255;
   subtype Color_Distance is Natural range 0 .. 195_075;

   function Histogram_Of (Color : Palettes.RGB_Color) return Histogram_Index
     with Post =>
       Histogram_Of'Result =
         Natural (Color.Red) / 8 * 1_024
           + Natural (Color.Green) / 8 * 32
           + Natural (Color.Blue) / 8;

   function Red_Bucket (Index : Histogram_Index) return Color_Bucket
     with Post => Red_Bucket'Result = Index / 1_024;

   function Green_Bucket (Index : Histogram_Index) return Color_Bucket
     with Post => Green_Bucket'Result = Index / 32 mod 32;

   function Blue_Bucket (Index : Histogram_Index) return Color_Bucket
     with Post => Blue_Bucket'Result = Index mod 32;

   function Clamp (Value : Long_Integer) return Byte
     with Post =>
       Clamp'Result =
         (if Value < 0 then 0 elsif Value > 255 then 255 else Byte (Value));

   function Difference (Left, Right : Byte) return Channel_Difference
     with Post =>
       Difference'Result =
         (if Left >= Right
          then Natural (Left - Right)
          else Natural (Right - Left));

   function Squared_Distance
     (Left : Palettes.RGB_Color;
      Right : Palettes.RGB_Color) return Color_Distance
     with Post =>
       Squared_Distance'Result =
         Difference (Left.Red, Right.Red) * Difference (Left.Red, Right.Red)
         + Difference (Left.Green, Right.Green) * Difference (Left.Green, Right.Green)
         + Difference (Left.Blue, Right.Blue) * Difference (Left.Blue, Right.Blue);
end Giflib.Internal.Quantization_Arithmetic;
