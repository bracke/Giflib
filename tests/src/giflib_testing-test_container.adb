with AUnit.Assertions;

with Giflib;
with Giflib.Errors;
with Giflib.Internal.Container;
with Giflib.Limits;
with Giflib.Palettes;
with Giflib.Results;
with Giflib.Streams;

package body Giflib_Testing.Test_Container is
   use AUnit.Assertions;
   use type Giflib.Block_Kind;
   use type Giflib.Byte;
   use type Giflib.Errors.Error_Code;
   use type Giflib.GIF_Version;
   use type Giflib.Image_Height;
   use type Giflib.Image_Width;
   use type Giflib.Limit_Kind;
   use type Giflib.Palettes.RGB_Color;
   use type Giflib.Palette_Index;
   use type Giflib.Source_Offset;

   procedure Parses_GIF87a_Global_Palette (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Parses_GIF89a_Without_Palette (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Rejects_Signatures_And_Truncation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Rejects_Dimensions_And_Limits (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("container");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Parses_GIF87a_Global_Palette'Access, "container.gif87a.global_palette");
      Register_Routine (T, Parses_GIF89a_Without_Palette'Access, "container.gif89a.no_palette");
      Register_Routine (T, Rejects_Signatures_And_Truncation'Access, "container.invalid_and_truncated");
      Register_Routine (T, Rejects_Dimensions_And_Limits'Access, "container.dimensions_and_limits");
   end Register_Tests;

   procedure Parses_GIF87a_Global_Palette (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  Independently specified, legal header/trailer-only GIF87a stream.
      Fixture : aliased constant Giflib.Streams.Byte_Array :=
        [71, 73, 70, 56, 55, 97,
         1, 0, 1, 0, 16#80#, 0, 0,
         0, 0, 0, 255, 255, 255,
         16#3B#];
      Source : Giflib.Streams.Memory_Source;
      Header : Giflib.Internal.Container.Header_Info;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source, Fixture'Unchecked_Access, Max_Transfer => 2);
      Outcome := Giflib.Internal.Container.Read_Header (Source, Giflib.Limits.Default_Limits, Header);
      Assert (Giflib.Results.Succeeded (Outcome), "valid GIF87a header failed");
      Assert (Header.Version = Giflib.GIF87a, "GIF87a version was not retained");
      Assert (Header.Width = 1 and then Header.Height = 1, "logical dimensions are wrong");
      Assert (Header.Has_Global_Palette and then Header.Global_Palette.Length = 2,
              "global palette descriptor is wrong");
      Assert (Header.Global_Palette.Colors (0) = (0, 0, 0), "first palette entry is wrong");
      Assert (Header.Global_Palette.Colors (1) = (255, 255, 255), "second palette entry is wrong");
      Outcome := Giflib.Internal.Container.Read_Trailer (Source);
      Assert (Giflib.Results.Succeeded (Outcome), "valid trailer failed");
      Assert (Source.Offset = 20, "parser did not stop after trailer");
   end Parses_GIF87a_Global_Palette;

   procedure Parses_GIF89a_Without_Palette (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Fixture : aliased constant Giflib.Streams.Byte_Array :=
        [71, 73, 70, 56, 57, 97,
         2, 0, 3, 0, 16#70#, 77, 49,
         16#3B#];
      Source : Giflib.Streams.Memory_Source;
      Header : Giflib.Internal.Container.Header_Info;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source, Fixture'Unchecked_Access);
      Outcome := Giflib.Internal.Container.Read_Header (Source, Giflib.Limits.Default_Limits, Header);
      Assert (Giflib.Results.Succeeded (Outcome), "valid GIF89a header failed");
      Assert (Header.Version = Giflib.GIF89a, "GIF89a version was not retained");
      Assert (Header.Width = 2 and then Header.Height = 3, "logical dimensions are wrong");
      Assert (not Header.Has_Global_Palette and then Header.Global_Palette.Length = 0,
              "absent global palette became present");
      Assert (Header.Color_Resolution = 8, "color resolution is wrong");
      Assert (Header.Background_Index = 77 and then Header.Pixel_Aspect_Ratio = 49,
              "logical screen fields were not retained");
      Outcome := Giflib.Internal.Container.Read_Trailer (Source);
      Assert (Giflib.Results.Succeeded (Outcome), "valid GIF89a trailer failed");
   end Parses_GIF89a_Without_Palette;

   procedure Rejects_Signatures_And_Truncation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Bad_Signature : aliased constant Giflib.Streams.Byte_Array :=
        [66, 65, 68, 56, 57, 97, 1, 0, 1, 0, 0, 0, 0];
      Bad_Version : aliased constant Giflib.Streams.Byte_Array :=
        [71, 73, 70, 57, 48, 97, 1, 0, 1, 0, 0, 0, 0];
      Short_Palette : aliased constant Giflib.Streams.Byte_Array :=
        [71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 16#80#, 0, 0, 1, 2];
      Source : Giflib.Streams.Memory_Source;
      Header : Giflib.Internal.Container.Header_Info;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source, Bad_Signature'Unchecked_Access);
      Outcome := Giflib.Internal.Container.Read_Header (Source, Giflib.Limits.Default_Limits, Header);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_Signature, "bad signature was accepted");

      Giflib.Streams.Open (Source, Bad_Version'Unchecked_Access);
      Outcome := Giflib.Internal.Container.Read_Header (Source, Giflib.Limits.Default_Limits, Header);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_Version, "bad version was accepted");

      Giflib.Streams.Open (Source, Short_Palette'Unchecked_Access);
      Outcome := Giflib.Internal.Container.Read_Header (Source, Giflib.Limits.Default_Limits, Header);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Truncated_Block, "truncated palette has wrong error");
      Assert (Outcome.First_Error.Context.Block = Giflib.Global_Color_Table_Block,
              "truncated palette lost block context");
   end Rejects_Signatures_And_Truncation;

   procedure Rejects_Dimensions_And_Limits (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Zero_Width : aliased constant Giflib.Streams.Byte_Array :=
        [71, 73, 70, 56, 57, 97, 0, 0, 1, 0, 0, 0, 0];
      Wide : aliased constant Giflib.Streams.Byte_Array :=
        [71, 73, 70, 56, 57, 97, 3, 0, 1, 0, 0, 0, 0];
      Tall : aliased constant Giflib.Streams.Byte_Array :=
        [71, 73, 70, 56, 57, 97, 1, 0, 3, 0, 0, 0, 0];
      Bad_Trailer : aliased constant Giflib.Streams.Byte_Array := [16#2C#];
      Source : Giflib.Streams.Memory_Source;
      Header : Giflib.Internal.Container.Header_Info;
      Constraints : Giflib.Limits.Limit_Set := Giflib.Limits.Default_Limits;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source, Zero_Width'Unchecked_Access);
      Outcome := Giflib.Internal.Container.Read_Header (Source, Constraints, Header);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_Dimensions, "zero width was accepted");

      Constraints.Max_Logical_Width := 2;
      Giflib.Streams.Open (Source, Wide'Unchecked_Access);
      Outcome := Giflib.Internal.Container.Read_Header (Source, Constraints, Header);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded, "width limit was ignored");
      Assert (Outcome.First_Error.Context.Limit = Giflib.Logical_Width_Limit,
              "width failure lost limit context");

      Constraints := Giflib.Limits.Default_Limits;
      Constraints.Max_Logical_Height := 2;
      Giflib.Streams.Open (Source, Tall'Unchecked_Access);
      Outcome := Giflib.Internal.Container.Read_Header (Source, Constraints, Header);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded
              and then Outcome.First_Error.Context.Limit = Giflib.Logical_Height_Limit,
              "height limit was ignored");

      Giflib.Streams.Open (Source, Bad_Trailer'Unchecked_Access);
      Outcome := Giflib.Internal.Container.Read_Trailer (Source);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_Block, "invalid trailer was accepted");
   end Rejects_Dimensions_And_Limits;
end Giflib_Testing.Test_Container;
