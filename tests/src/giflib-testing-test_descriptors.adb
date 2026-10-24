with AUnit.Assertions;

with Giflib.Errors;
with Giflib.Internal.Container;
with Giflib.Limits;
with Giflib.Palettes;
with Giflib.Results;
with Giflib.Streams;

package body Giflib.Testing.Test_Descriptors is
   use AUnit.Assertions;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Palettes.RGB_Color;

   procedure Uses_Global_Palette (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Local_Palette_Overrides_Global (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Validates_Geometry_And_Pixel_Limit (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Rejects_Missing_And_Truncated_Palettes (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("descriptors");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Uses_Global_Palette'Access, "descriptor.global_palette");
      Register_Routine (T, Local_Palette_Overrides_Global'Access, "descriptor.local_palette_and_flags");
      Register_Routine (T, Validates_Geometry_And_Pixel_Limit'Access, "descriptor.geometry_and_limit");
      Register_Routine (T, Rejects_Missing_And_Truncated_Palettes'Access,
                        "descriptor.missing_and_truncated_palette");
   end Register_Tests;

   procedure Uses_Global_Palette (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Fixture : aliased constant Giflib.Streams.Byte_Array :=
        [71, 73, 70, 56, 57, 97, 2, 0, 2, 0, 16#80#, 0, 0,
         1, 2, 3, 4, 5, 6,
         16#2C#, 1, 0, 0, 0, 1, 0, 2, 0, 0];
      Source : Giflib.Streams.Memory_Source (Fixture'Access);
      Header : Giflib.Internal.Container.Header_Info;
      Descriptor : Giflib.Internal.Container.Image_Descriptor;
      Palette : Giflib.Palettes.Palette;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source, Max_Transfer => 2);
      Outcome := Giflib.Internal.Container.Read_Header (Source, Giflib.Limits.Default_Limits, Header);
      Assert (Giflib.Results.Succeeded (Outcome), "fixture header failed");
      Outcome := Giflib.Internal.Container.Read_Image_Descriptor
        (Source, Header, Giflib.Limits.Default_Limits, Descriptor, Palette);
      Assert (Giflib.Results.Succeeded (Outcome), "valid image descriptor failed");
      Assert (Descriptor.Left = 1 and then Descriptor.Top = 0, "frame origin is wrong");
      Assert (Descriptor.Width = 1 and then Descriptor.Height = 2, "frame size is wrong");
      Assert (not Descriptor.Has_Local_Palette and then Palette.Length = 2,
              "global palette was not selected");
      Assert (Palette.Colors (1) = (4, 5, 6), "effective global palette is wrong");
   end Uses_Global_Palette;

   procedure Local_Palette_Overrides_Global (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Fixture : aliased constant Giflib.Streams.Byte_Array :=
        [71, 73, 70, 56, 57, 97, 2, 0, 2, 0, 0, 0, 0,
         16#2C#, 0, 0, 0, 0, 2, 0, 2, 0, 16#E0#,
         10, 20, 30, 40, 50, 60];
      Source : Giflib.Streams.Memory_Source (Fixture'Access);
      Header : Giflib.Internal.Container.Header_Info;
      Descriptor : Giflib.Internal.Container.Image_Descriptor;
      Palette : Giflib.Palettes.Palette;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source);
      Outcome := Giflib.Internal.Container.Read_Header (Source, Giflib.Limits.Default_Limits, Header);
      Assert (Giflib.Results.Succeeded (Outcome), "fixture header failed");
      Outcome := Giflib.Internal.Container.Read_Image_Descriptor
        (Source, Header, Giflib.Limits.Default_Limits, Descriptor, Palette);
      Assert (Giflib.Results.Succeeded (Outcome), "valid local palette failed");
      Assert (Descriptor.Has_Local_Palette, "local palette flag was lost");
      Assert (Descriptor.Interlaced and then Descriptor.Local_Palette_Sorted, "image flags were lost");
      Assert (Palette.Length = 2 and then Palette.Colors (0) = (10, 20, 30),
              "local palette was not selected");
   end Local_Palette_Overrides_Global;

   procedure Validates_Geometry_And_Pixel_Limit (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Out_Of_Bounds : aliased constant Giflib.Streams.Byte_Array :=
        [71, 73, 70, 56, 57, 97, 2, 0, 2, 0, 16#80#, 0, 0,
         0, 0, 0, 255, 255, 255,
         16#2C#, 1, 0, 0, 0, 2, 0, 1, 0, 0];
      Too_Many_Pixels : aliased constant Giflib.Streams.Byte_Array :=
        [71, 73, 70, 56, 57, 97, 3, 0, 3, 0, 16#80#, 0, 0,
         0, 0, 0, 255, 255, 255,
         16#2C#, 0, 0, 0, 0, 3, 0, 3, 0, 0];
      Source : Giflib.Streams.Memory_Source (Out_Of_Bounds'Access);
      Pixel_Source : Giflib.Streams.Memory_Source (Too_Many_Pixels'Access);
      Header : Giflib.Internal.Container.Header_Info;
      Descriptor : Giflib.Internal.Container.Image_Descriptor;
      Palette : Giflib.Palettes.Palette;
      Constraints : Giflib.Limits.Limit_Set := Giflib.Limits.Default_Limits;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source);
      Outcome := Giflib.Internal.Container.Read_Header (Source, Constraints, Header);
      Assert (Giflib.Results.Succeeded (Outcome), "bounds fixture header failed");
      Outcome := Giflib.Internal.Container.Read_Image_Descriptor
        (Source, Header, Constraints, Descriptor, Palette);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Frame_Out_Of_Bounds,
              "out-of-bounds frame was accepted");

      Constraints.Max_Frame_Pixels := 8;
      Giflib.Streams.Open (Pixel_Source);
      Outcome := Giflib.Internal.Container.Read_Header (Pixel_Source, Constraints, Header);
      Assert (Giflib.Results.Succeeded (Outcome), "pixel-limit fixture header failed");
      Outcome := Giflib.Internal.Container.Read_Image_Descriptor
        (Pixel_Source, Header, Constraints, Descriptor, Palette);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded,
              "frame pixel limit was ignored");
      Assert (Outcome.First_Error.Context.Limit = Giflib.Frame_Pixel_Limit,
              "frame pixel limit context was lost");
   end Validates_Geometry_And_Pixel_Limit;

   procedure Rejects_Missing_And_Truncated_Palettes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Missing : aliased constant Giflib.Streams.Byte_Array :=
        [71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 0, 0, 0,
         16#2C#, 0, 0, 0, 0, 1, 0, 1, 0, 0];
      Truncated : aliased constant Giflib.Streams.Byte_Array :=
        [71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 0, 0, 0,
         16#2C#, 0, 0, 0, 0, 1, 0, 1, 0, 16#80#, 1, 2, 3];
      Source : Giflib.Streams.Memory_Source (Missing'Access);
      Truncated_Source : Giflib.Streams.Memory_Source (Truncated'Access);
      Header : Giflib.Internal.Container.Header_Info;
      Descriptor : Giflib.Internal.Container.Image_Descriptor;
      Palette : Giflib.Palettes.Palette;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source);
      Outcome := Giflib.Internal.Container.Read_Header (Source, Giflib.Limits.Default_Limits, Header);
      Assert (Giflib.Results.Succeeded (Outcome), "missing-palette fixture header failed");
      Outcome := Giflib.Internal.Container.Read_Image_Descriptor
        (Source, Header, Giflib.Limits.Default_Limits, Descriptor, Palette);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Missing_Color_Table,
              "missing effective palette was accepted");

      Giflib.Streams.Open (Truncated_Source);
      Outcome := Giflib.Internal.Container.Read_Header
        (Truncated_Source, Giflib.Limits.Default_Limits, Header);
      Assert (Giflib.Results.Succeeded (Outcome), "truncated-palette fixture header failed");
      Outcome := Giflib.Internal.Container.Read_Image_Descriptor
        (Truncated_Source, Header, Giflib.Limits.Default_Limits, Descriptor, Palette);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Truncated_Block,
              "truncated local palette has wrong error");
   end Rejects_Missing_And_Truncated_Palettes;
end Giflib.Testing.Test_Descriptors;
