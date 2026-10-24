with AUnit.Assertions;

with Giflib.Errors;
with Giflib.Internal.Container;
with Giflib.Internal.Descriptor_Arithmetic;
with Giflib.Internal.Geometry_Arithmetic;
with Giflib.Limits;
with Giflib.Palettes;
with Giflib.Results;
with Giflib.Streams;

package body Giflib.Testing.Test_Container is
   use AUnit.Assertions;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Palettes.RGB_Color;

   procedure Parses_GIF87a_Global_Palette (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Parses_GIF89a_Without_Palette (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Rejects_Signatures_And_Truncation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Rejects_Dimensions_And_Limits (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Accepts_Geometry_Boundaries (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Geometry_Arithmetic_Is_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Descriptor_Arithmetic_Is_Exact (T : in out AUnit.Test_Cases.Test_Case'Class);

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
      Register_Routine (T, Accepts_Geometry_Boundaries'Access,
                        "container.geometry_255_256_257");
      Register_Routine (T, Geometry_Arithmetic_Is_Bounded'Access,
                        "container.geometry_arithmetic");
      Register_Routine (T, Descriptor_Arithmetic_Is_Exact'Access,
                        "container.descriptor_arithmetic");
   end Register_Tests;

   procedure Descriptor_Arithmetic_Is_Exact (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      package Arithmetic renames Giflib.Internal.Descriptor_Arithmetic;
   begin
      for Resolution in Arithmetic.Color_Resolution loop
         for Has_Palette in Boolean loop
            for Sorted in Boolean loop
               for Size in Arithmetic.Palette_Size_Code loop
                  declare
                     Packed : constant Giflib.Byte :=
                       Arithmetic.Encode_Logical_Screen
                         (Resolution, Has_Palette, Sorted, Size);
                     Fields : constant Arithmetic.Logical_Screen_Fields :=
                       Arithmetic.Decode_Logical_Screen (Packed);
                  begin
                     Assert
                       (Fields.Has_Global_Palette = Has_Palette
                        and then Fields.Color_Resolution = Resolution
                        and then Fields.Global_Palette_Sorted = Sorted
                        and then Fields.Palette_Length = 2 ** (Size + 1),
                        "logical-screen packed fields did not round trip");
                  end;
               end loop;
            end loop;
         end loop;
      end loop;

      for Has_Palette in Boolean loop
         for Interlaced in Boolean loop
            for Sorted in Boolean loop
               for Size in Arithmetic.Palette_Size_Code loop
                  declare
                     Packed : constant Giflib.Byte :=
                       Arithmetic.Encode_Image
                         (Has_Palette, Interlaced, Sorted, Size);
                     Fields : constant Arithmetic.Image_Fields :=
                       Arithmetic.Decode_Image (Packed);
                  begin
                     Assert
                       (Fields.Has_Local_Palette = Has_Palette
                        and then Fields.Interlaced = Interlaced
                        and then Fields.Local_Palette_Sorted = Sorted
                        and then Fields.Reserved_Bits = 0
                        and then Fields.Palette_Length = 2 ** (Size + 1),
                        "image-descriptor packed fields did not round trip");
                  end;
               end loop;
            end loop;
         end loop;
      end loop;

      for Packed in Giflib.Byte loop
         declare
            Screen : constant Arithmetic.Logical_Screen_Fields :=
              Arithmetic.Decode_Logical_Screen (Packed);
            Image : constant Arithmetic.Image_Fields :=
              Arithmetic.Decode_Image (Packed);
         begin
            Assert
              (Screen.Palette_Length = Image.Palette_Length
               and then Image.Reserved_Bits =
                 Giflib.Byte (((Natural (Packed) / 8) mod 4) * 8),
               "packed palette-size bits were decoded inconsistently");
         end;
      end loop;
   end Descriptor_Arithmetic_Is_Exact;

   procedure Geometry_Arithmetic_Is_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      package Arithmetic renames Giflib.Internal.Geometry_Arithmetic;
      Full : constant Arithmetic.Rectangle_Analysis :=
        Arithmetic.Analyze_Rectangle (0, 0, 65_535, 65_535, 65_535, 65_535);
      Edge : constant Arithmetic.Rectangle_Analysis :=
        Arithmetic.Analyze_Rectangle (65_534, 65_534, 1, 1, 65_535, 65_535);
      Outside : constant Arithmetic.Rectangle_Analysis :=
        Arithmetic.Analyze_Rectangle (65_535, 65_535, 1, 1, 65_535, 65_535);
   begin
      Assert (Full.Fits and then Full.Pixel_Area = 4_294_836_225,
              "maximum GIF canvas geometry is wrong");
      Assert (Edge.Fits and then Edge.Right_Edge = 65_535 and then Edge.Bottom_Edge = 65_535,
              "rectangle touching the canvas edge was rejected");
      Assert (not Outside.Fits
              and then Outside.Right_Edge = 65_536
              and then Outside.Bottom_Edge = 65_536,
              "out-of-bounds rectangle was accepted");
   end Geometry_Arithmetic_Is_Bounded;

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
      Source : Giflib.Streams.Memory_Source (Fixture'Access);
      Header : Giflib.Internal.Container.Header_Info;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source);
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
      Source : Giflib.Streams.Memory_Source (Bad_Signature'Access);
      Version_Source : Giflib.Streams.Memory_Source (Bad_Version'Access);
      Palette_Source : Giflib.Streams.Memory_Source (Short_Palette'Access);
      Header : Giflib.Internal.Container.Header_Info;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source);
      Outcome := Giflib.Internal.Container.Read_Header (Source, Giflib.Limits.Default_Limits, Header);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_Signature, "bad signature was accepted");

      Giflib.Streams.Open (Version_Source);
      Outcome := Giflib.Internal.Container.Read_Header
        (Version_Source, Giflib.Limits.Default_Limits, Header);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_Version, "bad version was accepted");

      Giflib.Streams.Open (Palette_Source);
      Outcome := Giflib.Internal.Container.Read_Header
        (Palette_Source, Giflib.Limits.Default_Limits, Header);
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
      Source : Giflib.Streams.Memory_Source (Zero_Width'Access);
      Wide_Source : Giflib.Streams.Memory_Source (Wide'Access);
      Tall_Source : Giflib.Streams.Memory_Source (Tall'Access);
      Trailer_Source : Giflib.Streams.Memory_Source (Bad_Trailer'Access);
      Header : Giflib.Internal.Container.Header_Info;
      Constraints : Giflib.Limits.Limit_Set := Giflib.Limits.Default_Limits;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source);
      Outcome := Giflib.Internal.Container.Read_Header (Source, Constraints, Header);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_Dimensions, "zero width was accepted");

      Constraints.Max_Logical_Width := 2;
      Giflib.Streams.Open (Wide_Source);
      Outcome := Giflib.Internal.Container.Read_Header (Wide_Source, Constraints, Header);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded, "width limit was ignored");
      Assert (Outcome.First_Error.Context.Limit = Giflib.Logical_Width_Limit,
              "width failure lost limit context");

      Constraints := Giflib.Limits.Default_Limits;
      Constraints.Max_Logical_Height := 2;
      Giflib.Streams.Open (Tall_Source);
      Outcome := Giflib.Internal.Container.Read_Header (Tall_Source, Constraints, Header);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded
              and then Outcome.First_Error.Context.Limit = Giflib.Logical_Height_Limit,
              "height limit was ignored");

      Giflib.Streams.Open (Trailer_Source);
      Outcome := Giflib.Internal.Container.Read_Trailer (Trailer_Source);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_Block, "invalid trailer was accepted");
   end Rejects_Dimensions_And_Limits;

   procedure Accepts_Geometry_Boundaries
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      type Dimension_Array is array (Positive range <>) of Natural;
      Dimensions : constant Dimension_Array := [255, 256, 257];
      Header : Giflib.Internal.Container.Header_Info;
      Outcome : Giflib.Results.Result;

      function Fixture (Width, Height : Natural) return Giflib.Streams.Byte_Array is
      begin
         return
           [71, 73, 70, 56, 57, 97,
            Giflib.Byte (Width mod 256), Giflib.Byte (Width / 256),
            Giflib.Byte (Height mod 256), Giflib.Byte (Height / 256),
            0, 0, 0];
      end Fixture;
   begin
      for Dimension of Dimensions loop
         declare
            Wide : aliased constant Giflib.Streams.Byte_Array :=
              Fixture (Dimension, 1);
            Tall : aliased constant Giflib.Streams.Byte_Array :=
              Fixture (1, Dimension);
            Wide_Source : Giflib.Streams.Memory_Source (Wide'Access);
            Tall_Source : Giflib.Streams.Memory_Source (Tall'Access);
         begin
            Giflib.Streams.Open (Wide_Source);
            Outcome := Giflib.Internal.Container.Read_Header
              (Wide_Source, Giflib.Limits.Default_Limits, Header);
            Assert (Giflib.Results.Succeeded (Outcome)
                    and then Natural (Header.Width) = Dimension
                    and then Header.Height = 1,
                    "width boundary was rejected or changed");

            Giflib.Streams.Open (Tall_Source);
            Outcome := Giflib.Internal.Container.Read_Header
              (Tall_Source, Giflib.Limits.Default_Limits, Header);
            Assert (Giflib.Results.Succeeded (Outcome)
                    and then Header.Width = 1
                    and then Natural (Header.Height) = Dimension,
                    "height boundary was rejected or changed");
         end;
      end loop;
   end Accepts_Geometry_Boundaries;
end Giflib.Testing.Test_Container;
