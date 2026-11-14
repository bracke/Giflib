separate (Giflib.Testing.Test_Compositing)
procedure Disposal_Three_Restores_Previous (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Fixture : aliased constant Giflib.Streams.Byte_Array :=
     Header & GCE (1) & Two_Red_Pixels &
     GCE (3) & One_Pixel (0, 2) &
     GCE (1) & One_Pixel (1, 3) & [16#3B#];
   Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
   Decoder : Giflib.Decoding.Decoder (Source'Access);
   Canvas : Giflib.Streams.Byte_Array (1 .. 8);
   Info : Giflib.Decoding.Frame_Info;
   Outcome : Giflib.Results.Result;
begin
   Begin_Decoder (Source, Decoder, Outcome => Outcome);
   Next_Canvas (Decoder, Canvas, Info, Outcome);
   Next_Canvas (Decoder, Canvas, Info, Outcome);
   Assert (Canvas = [0, 255, 0, 255, 255, 0, 0, 255], "disposal-3 frame draw is wrong");
   Next_Canvas (Decoder, Canvas, Info, Outcome);
   Assert (Canvas = [255, 0, 0, 255, 0, 0, 255, 255],
           "disposal 3 did not restore previous rectangle");
end Disposal_Three_Restores_Previous;
