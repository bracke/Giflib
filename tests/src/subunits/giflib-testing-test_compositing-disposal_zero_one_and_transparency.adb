separate (Giflib.Testing.Test_Compositing)
procedure Disposal_Zero_One_And_Transparency (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Fixture : aliased constant Giflib.Streams.Byte_Array :=
     Header & GCE (0) & Two_Red_Pixels &
     GCE (1, True, 0) & One_Pixel (0, 0) &
     GCE (1) & One_Pixel (1, 3) & [16#3B#];
   Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
   Decoder : Giflib.Decoding.Decoder (Source'Access);
   Canvas : Giflib.Streams.Byte_Array (1 .. 8);
   Info : Giflib.Decoding.Frame_Info;
   Outcome : Giflib.Results.Result;
begin
   Begin_Decoder (Source, Decoder, Outcome => Outcome);
   Assert (Giflib.Results.Succeeded (Outcome), "composited decoder setup failed");
   Next_Canvas (Decoder, Canvas, Info, Outcome);
   Assert (Canvas = [255, 0, 0, 255, 255, 0, 0, 255], "first retained canvas is wrong");
   Next_Canvas (Decoder, Canvas, Info, Outcome);
   Assert (Canvas = [255, 0, 0, 255, 255, 0, 0, 255],
           "transparent index painted over canvas");
   Next_Canvas (Decoder, Canvas, Info, Outcome);
   Assert (Canvas = [255, 0, 0, 255, 0, 0, 255, 255],
           "disposal 0/1 did not retain canvas");
end Disposal_Zero_One_And_Transparency;
