package body Giflib.Internal.LZW_Encoder_Input is
   function Element
     (Input : Streams.Byte_Array;
      Ordinal : Natural;
      Layout : Interlacing.Traversal_Layout) return Byte
   is
      Position : Natural := Ordinal;
   begin
      if Layout.Is_Interlaced then
         Position :=
           Interlacing.Row_For_Ordinal
             (Layout.Height, Ordinal / Layout.Width)
           * Layout.Width + Ordinal mod Layout.Width;
      end if;
      return Input (Input'First + Position);
   end Element;
end Giflib.Internal.LZW_Encoder_Input;
