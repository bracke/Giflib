separate (Giflib.Testing.Test_Quantization)
procedure Pixel_Access_Is_Checked
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   package Pixels renames Giflib.Internal.Quantization_Pixels;
   Data : aliased constant Giflib.Streams.Byte_Array := [12, 34, 56];
   Valid_View : constant Giflib.Images.Image_View :=
     (Format => Giflib.RGB_24, Width => 1, Height => 1, Stride => 3,
      Accessible_Bytes => 3, Data => Data'Access);
   Short_View : constant Giflib.Images.Image_View :=
     (Format => Giflib.RGB_24, Width => 1, Height => 1, Stride => 3,
      Accessible_Bytes => 2, Data => Data'Access);
   Read : Pixels.Pixel_Result;
begin
   Read := Pixels.Read_Pixel (Valid_View, 0, 0);
   Assert
     (Read.Valid and then Read.Value.Color = (12, 34, 56),
      "valid pixel access returned the wrong color");
   Read := Pixels.Read_Pixel (Valid_View, 1, 0);
   Assert (not Read.Valid, "out-of-range pixel access was accepted");
   Read := Pixels.Read_Pixel (Short_View, 0, 0);
   Assert (not Read.Valid, "short pixel storage was accessed");
end Pixel_Access_Is_Checked;

