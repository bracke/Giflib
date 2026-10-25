package Giflib.Internal.Interlacing with SPARK_Mode is
   pragma Pure;

   type Traversal_Layout (Is_Interlaced : Boolean := False) is record
      case Is_Interlaced is
         when False =>
            null;
         when True =>
            Width : Positive;
            Height : Positive;
      end case;
   end record;
   Sequential_Layout : constant Traversal_Layout :=
     (Is_Interlaced => False);

   function Is_Valid
     (Layout : Traversal_Layout;
      Length : Natural) return Boolean is
     (not Layout.Is_Interlaced
      or else
        (Layout.Width <= 65_535
         and then Layout.Height <= 65_535
         and then Layout.Width <= Natural'Last / Layout.Height
         and then Layout.Width * Layout.Height = Length));

   --  Maps a row's ordinal in GIF interlace transmission order to its
   --  zero-based row in the image. Height = 0 or Ordinal >= Height returns
   --  Height as an invalid sentinel.
   function Row_For_Ordinal (Height, Ordinal : Natural) return Natural
     with Pre => Height <= 65_535 and then Ordinal <= 65_535,
          Post => Row_For_Ordinal'Result <= Height;
end Giflib.Internal.Interlacing;
