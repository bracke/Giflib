with Giflib.Streams;
with Giflib.Internal.Interlacing;

package Giflib.Internal.LZW_Encoder_Input
  with Preelaborate
is
   pragma Warnings
     (Off, "aspect * not enforced on inlined subprogram *");
   function Element
     (Input : Streams.Byte_Array;
      Ordinal : Natural;
      Layout : Interlacing.Traversal_Layout) return Byte
     with Pre => Ordinal < Input'Length
                 and then Interlacing.Is_Valid (Layout, Input'Length);
   pragma Inline_Always (Element);
   pragma Warnings
     (On, "aspect * not enforced on inlined subprogram *");
end Giflib.Internal.LZW_Encoder_Input;
