separate (Giflib.Testing.Test_Compositing)
procedure Disposal_Two_Restores_Background (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Fixture : aliased constant Giflib.Streams.Byte_Array :=
     Header & GCE (1) & Two_Red_Pixels &
     GCE (2) & One_Pixel (0, 2) &
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
   Assert (Canvas = [0, 255, 0, 255, 255, 0, 0, 255], "disposal-2 frame draw is wrong");
   Next_Canvas (Decoder, Canvas, Info, Outcome);
   Assert (Canvas = [0, 0, 0, 255, 0, 0, 255, 255],
           "disposal 2 did not restore logical background");
end Disposal_Two_Restores_Background;
