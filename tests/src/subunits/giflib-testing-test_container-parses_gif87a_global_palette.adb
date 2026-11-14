separate (Giflib.Testing.Test_Container)
procedure Parses_GIF87a_Global_Palette (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   --  Independently specified, legal header/trailer-only GIF87a stream.
   Fixture : aliased constant Giflib.Streams.Byte_Array :=
     [71, 73, 70, 56, 55, 97,
      1, 0, 1, 0, 16#80#, 0, 0,
      0, 0, 0, 255, 255, 255,
      16#3B#];
   Source : Giflib.Streams.Memory_Source (Fixture'Access);
   Header : Giflib.Internal.Container.Header_Info;
   Outcome : Giflib.Results.Result;
begin
   Giflib.Streams.Open (Source, Max_Transfer => 2);
   Outcome := Giflib.Internal.Container.Read_Header (Source, Giflib.Limits.Default_Limits, Header);
   Assert (Giflib.Results.Succeeded (Outcome), "valid GIF87a header failed");
   Assert (Header.Version = Giflib.GIF87a, "GIF87a version was not retained");
   Assert (Header.Width = 1 and then Header.Height = 1, "logical dimensions are wrong");
   Assert (Header.Has_Global_Palette and then Header.Global_Palette.Length = 2,
           "global palette descriptor is wrong");
   Assert (Header.Global_Palette.Colors (0) = (0, 0, 0), "first palette entry is wrong");
   Assert (Header.Global_Palette.Colors (1) = (255, 255, 255), "second palette entry is wrong");
   Assert (Source.Offset = 19, "header parser consumed the following trailer");
end Parses_GIF87a_Global_Palette;
