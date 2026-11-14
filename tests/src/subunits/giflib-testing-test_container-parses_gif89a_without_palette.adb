separate (Giflib.Testing.Test_Container)
procedure Parses_GIF89a_Without_Palette (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Fixture : aliased constant Giflib.Streams.Byte_Array :=
     [71, 73, 70, 56, 57, 97,
      2, 0, 3, 0, 16#70#, 77, 49,
      16#3B#];
   Source : Giflib.Streams.Memory_Source (Fixture'Access);
   Header : Giflib.Internal.Container.Header_Info;
   Outcome : Giflib.Results.Result;
begin
   Giflib.Streams.Open (Source);
   Outcome := Giflib.Internal.Container.Read_Header (Source, Giflib.Limits.Default_Limits, Header);
   Assert (Giflib.Results.Succeeded (Outcome), "valid GIF89a header failed");
   Assert (Header.Version = Giflib.GIF89a, "GIF89a version was not retained");
   Assert (Header.Width = 2 and then Header.Height = 3, "logical dimensions are wrong");
   Assert (not Header.Has_Global_Palette,
           "absent global palette became present");
   Assert (Header.Color_Resolution = 8, "color resolution is wrong");
   Assert (Header.Background_Index = 77 and then Header.Pixel_Aspect_Ratio = 49,
           "logical screen fields were not retained");
   Assert (Source.Offset = 13, "header parser consumed the following trailer");
end Parses_GIF89a_Without_Palette;
