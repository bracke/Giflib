separate (Giflib.Testing.Test_Foundation)
procedure Capabilities_Are_Advertised
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
begin
   Assert (Giflib.Capabilities.Memory_Streams, "memory streams must be advertised");
   Assert (Giflib.Capabilities.Foundation_API, "foundation capability must be advertised");
   Assert (Giflib.Capabilities.Container_Decoding, "container decoder is not advertised");
   Assert (Giflib.Capabilities.Indexed_Decoding, "indexed decoder is not advertised");
   Assert (Giflib.Capabilities.Composited_Decoding,
           "composited decoder is not advertised");
   Assert (Giflib.Capabilities.Indexed_Encoding, "indexed encoder is not advertised");
   Assert (Giflib.Capabilities.Animation_Encoding, "animation encoder is not advertised");
   Assert (Giflib.Capabilities.Truecolor_Encoding, "truecolor encoder is not advertised");
   Assert (Giflib.Capabilities.Quantization, "quantization is not advertised");
   Assert (Giflib.Capabilities.Frame_Optimization, "optimization is not advertised");
   Assert (Giflib.Image_Width'First = 1, "image widths must be positive");
   Assert (Giflib.Coordinate'First = 0, "coordinates must be zero based");
end Capabilities_Are_Advertised;

