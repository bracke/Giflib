package Giflib.Internal.Interlacing with SPARK_Mode is
   pragma Pure;

   --  Maps a row's ordinal in GIF interlace transmission order to its
   --  zero-based row in the image. Height = 0 or Ordinal >= Height returns
   --  Height as an invalid sentinel.
   function Row_For_Ordinal (Height, Ordinal : Natural) return Natural
     with Pre => Height <= 65_535 and then Ordinal <= 65_535,
          Post => Row_For_Ordinal'Result <= Height;
end Giflib.Internal.Interlacing;
