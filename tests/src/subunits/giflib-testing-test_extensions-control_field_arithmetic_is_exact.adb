separate (Giflib.Testing.Test_Extensions)
procedure Control_Field_Arithmetic_Is_Exact (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   package Arithmetic renames Giflib.Internal.Extension_Arithmetic;
   Control : constant Giflib.Frames.Graphic_Control :=
     (Disposal => 3,
      User_Input => True,
      Delay_CS => 65_535,
      Has_Transparency => True,
      Transparent_Index => 255);
   Packed : constant Giflib.Byte := Arithmetic.Encode_Graphic_Control (Control);
   Decoded : constant Giflib.Frames.Graphic_Control :=
     Arithmetic.Decode_Graphic_Control
       (Packed,
        Arithmetic.Low_Byte (Natural (Control.Delay_CS)),
        Arithmetic.High_Byte (Natural (Control.Delay_CS)),
        Giflib.Byte (Control.Transparent_Index));
begin
   Assert (Packed = 15 and then Decoded = Control,
           "graphic-control packing round trip is wrong");
   Assert (Arithmetic.Decode_U16_LE (16#34#, 16#12#) = 16#1234#,
           "extension little-endian field decode is wrong");
   Assert (not Arithmetic.Has_Reserved_GCE_Bits (31)
           and then Arithmetic.Has_Reserved_GCE_Bits (32),
           "graphic-control reserved-bit classification is wrong");
end Control_Field_Arithmetic_Is_Exact;
