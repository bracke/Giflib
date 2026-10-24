with AUnit.Assertions;

with Giflib;
with Giflib.Internal.Container;
with Giflib.Internal.Image_Data;
with Giflib.Internal.Interlacing;
with Giflib.Limits;
with Giflib.Palettes;
with Giflib.Results;
with Giflib.Streams;

package body Giflib_Testing.Test_Interlacing is
   use AUnit.Assertions;
   use type Giflib.Streams.Byte_Array;

   procedure Maps_All_Four_Passes (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Maps_Tiny_Heights (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Image_Decode_Writes_Row_Major (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("interlacing");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Maps_All_Four_Passes'Access, "interlace.four_passes");
      Register_Routine (T, Maps_Tiny_Heights'Access, "interlace.tiny_heights");
      Register_Routine (T, Image_Decode_Writes_Row_Major'Access, "interlace.decode_row_major");
   end Register_Tests;

   procedure Assert_Order (Height : Positive; Expected : Giflib.Streams.Byte_Array) is
   begin
      for Ordinal in 0 .. Height - 1 loop
         Assert
           (Giflib.Internal.Interlacing.Row_For_Ordinal (Height, Ordinal) = Natural (Expected (Ordinal + 1)),
            "wrong row for height" & Height'Image & " ordinal" & Ordinal'Image);
      end loop;
   end Assert_Order;

   procedure Maps_All_Four_Passes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert_Order (8, [0, 4, 2, 6, 1, 3, 5, 7]);
      Assert_Order (9, [0, 8, 4, 2, 6, 1, 3, 5, 7]);
      Assert_Order (10, [0, 8, 4, 2, 6, 1, 3, 5, 7, 9]);
   end Maps_All_Four_Passes;

   procedure Maps_Tiny_Heights (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert_Order (1, [0]);
      Assert_Order (2, [0, 1]);
      Assert_Order (3, [0, 2, 1]);
      Assert_Order (4, [0, 2, 1, 3]);
      Assert_Order (5, [0, 4, 2, 1, 3]);
      Assert (Giflib.Internal.Interlacing.Row_For_Ordinal (4, 4) = 4,
              "out-of-range ordinal did not return sentinel");
   end Maps_Tiny_Heights;

   procedure Image_Decode_Writes_Row_Major (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  Minimum size 3; Clear, literals 0..7, End. The transition to five
      --  bits occurs before literal 7.
      Input : aliased constant Giflib.Streams.Byte_Array := [3, 6, 8, 33, 67, 101, 39, 1, 0];
      Source : Giflib.Streams.Memory_Source;
      Descriptor : constant Giflib.Internal.Container.Image_Descriptor :=
        (Left => 0, Top => 0, Width => 2, Height => 4, Interlaced => True, others => <>);
      Palette : Giflib.Palettes.Palette;
      Output : Giflib.Streams.Byte_Array (1 .. 8);
      Pixels : Giflib.Pixel_Count := 0;
      Compressed : Giflib.Byte_Count := 0;
      Outcome : Giflib.Results.Result;
   begin
      Palette.Length := 8;
      Giflib.Streams.Open (Source, Input'Unchecked_Access, Max_Transfer => 1);
      Outcome := Giflib.Internal.Image_Data.Decode_Indices
        (Source, Descriptor, Palette, Giflib.Limits.Default_Limits,
         Pixels, Compressed, Output);
      Assert (Giflib.Results.Succeeded (Outcome), "interlaced image data failed");
      Assert (Output = [0, 1, 4, 5, 2, 3, 6, 7], "interlaced output is not row-major");
   end Image_Decode_Writes_Row_Major;
end Giflib_Testing.Test_Interlacing;
