with Giflib.Streams;
with Giflib.Internal.Interlacing;

package Giflib.Internal.LZW_Encoder_Input
  with Preelaborate
is
   function Element
     (Input : Streams.Byte_Array;
      Ordinal : Natural;
      Layout : Interlacing.Traversal_Layout) return Byte
     with Pre => Ordinal < Input'Length
                 and then Interlacing.Is_Valid (Layout, Input'Length);
end Giflib.Internal.LZW_Encoder_Input;
