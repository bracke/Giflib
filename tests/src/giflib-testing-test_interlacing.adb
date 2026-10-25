with AUnit.Assertions;

with Giflib.Internal.Image_Data;
with Giflib.Internal.Interlacing;
with Giflib.Internal.LZW;
with Giflib.Internal.Ownership;
with Giflib.Limits;
with Giflib.Palettes;
with Giflib.Results;
with Giflib.Streams;

package body Giflib.Testing.Test_Interlacing is
   use AUnit.Assertions;
   use type Giflib.Internal.Ownership.Allocation_Status;
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
      Source : Giflib.Streams.Memory_Source (Input'Access);
      Context : Giflib.Internal.LZW.Workspace_Handle;
      Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
      Fault : Giflib.Internal.Ownership.Fault_State;
      Palette : Giflib.Palettes.Palette;
      Output : Giflib.Streams.Byte_Array (1 .. 8);
      Pixels : Giflib.Pixel_Count := 0;
      Compressed : Giflib.Byte_Count := 0;
      Outcome : Giflib.Results.Result;
   begin
      declare
         Allocation : constant Giflib.Internal.Ownership.Allocation_Outcome :=
           Giflib.Internal.LZW.Ensure
             (Context, Budget, Fault, Giflib.Byte_Count'Last);
      begin
         Assert
           (Allocation.Status = Giflib.Internal.Ownership.Allocation_Ready,
            "could not allocate interlace LZW workspace");
      end;
      Palette.Length := 8;
      Giflib.Streams.Open (Source, Max_Transfer => 1);
      Outcome := Giflib.Internal.Image_Data.Decode_Indices
        (Context, Source, 2, 4, True, Palette, Giflib.Limits.Default_Limits,
         Pixels, Compressed, Output);
      Assert (Giflib.Results.Succeeded (Outcome), "interlaced image data failed");
      Assert (Output = [0, 1, 4, 5, 2, 3, 6, 7], "interlaced output is not row-major");
      Assert (Giflib.Internal.LZW.Release (Context, Budget),
              "interlace LZW workspace ledger mismatch");
   end Image_Decode_Writes_Row_Major;
end Giflib.Testing.Test_Interlacing;
