with AUnit.Assertions;

with Giflib.Errors;
with Giflib.Internal.Container;
with Giflib.Internal.Image_Data;
with Giflib.Internal.LZW;
with Giflib.Internal.Ownership;
with Giflib.Limits;
with Giflib.Palettes;
with Giflib.Results;
with Giflib.Streams;

package body Giflib.Testing.Test_Image_Data is
   use AUnit.Assertions;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Internal.Ownership.Allocation_Status;
   use type Giflib.Streams.Byte_Array;

   procedure Decodes_Into_Caller_Buffer (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Rejects_Palette_Index_And_Truncation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Enforces_Buffer_And_Total_Budgets (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("image_data");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Decodes_Into_Caller_Buffer'Access, "image_data.caller_buffer");
      Register_Routine (T, Rejects_Palette_Index_And_Truncation'Access,
                        "image_data.palette_and_truncation");
      Register_Routine (T, Enforces_Buffer_And_Total_Budgets'Access, "image_data.buffer_and_budgets");
   end Register_Tests;

   function Descriptor_1x2 return Giflib.Internal.Container.Image_Descriptor is
   begin
      return
        (Left => 0,
         Top => 0,
         Width => 1,
         Height => 2,
         Has_Local_Palette => False,
         Local_Palette => <>,
         Interlaced => False,
         Local_Palette_Sorted => False,
         Reserved_Bits => 0,
         Has_Packed_Field_Offset => False,
         Packed_Field_Offset => 0);
   end Descriptor_1x2;

   function Two_Color_Palette return Giflib.Palettes.Palette is
      Item : Giflib.Palettes.Palette;
   begin
      Item.Length := 2;
      Item.Colors (0) := (0, 0, 0);
      Item.Colors (1) := (255, 255, 255);
      return Item;
   end Two_Color_Palette;

   procedure Prepare
     (Context : in out Giflib.Internal.LZW.Workspace_Handle;
      Budget : aliased in out Giflib.Internal.Ownership.Byte_Budget;
      Fault : in out Giflib.Internal.Ownership.Fault_State)
   is
      Allocation : constant Giflib.Internal.Ownership.Allocation_Outcome :=
        Giflib.Internal.LZW.Ensure
          (Context, Budget, Fault, Giflib.Byte_Count'Last);
   begin
      Assert
        (Allocation.Status = Giflib.Internal.Ownership.Allocation_Ready,
         "could not allocate test LZW workspace");
   end Prepare;

   procedure Decodes_Into_Caller_Buffer (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  Minimum size 2; codes Clear, 0, 1, End packed LSB-first.
      Input : aliased constant Giflib.Streams.Byte_Array := [2, 2, 16#44#, 16#0A#, 0];
      Source : Giflib.Streams.Memory_Source (Input'Access);
      Context : Giflib.Internal.LZW.Workspace_Handle;
      Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
      Fault : Giflib.Internal.Ownership.Fault_State;
      Output : Giflib.Streams.Byte_Array (1 .. 2) := [99, 99];
      Pixels : Giflib.Pixel_Count := 0;
      Compressed : Giflib.Byte_Count := 0;
      Outcome : Giflib.Results.Result;
   begin
      Prepare (Context, Budget, Fault);
      Giflib.Streams.Open (Source, Max_Transfer => 1);
      Outcome := Giflib.Internal.Image_Data.Decode_Indices
        (Context,
         Source,
         Descriptor_1x2,
         Two_Color_Palette,
         Giflib.Limits.Default_Limits,
         Pixels,
         Compressed,
         Output,
         Frame => 2);
      Assert (Giflib.Results.Succeeded (Outcome), "valid image data failed");
      Assert (Output = [0, 1], "caller-owned output is wrong");
      Assert (Pixels = 2, "decoded pixel accounting is wrong");
      Assert (Compressed = 2, "compressed byte accounting is wrong");
      Assert (Giflib.Internal.LZW.Release (Context, Budget),
              "image-data LZW workspace ledger mismatch");
   end Decodes_Into_Caller_Buffer;

   procedure Rejects_Palette_Index_And_Truncation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  Clear, literal 2, End. Literal 2 is outside a two-entry palette.
      Bad_Index : aliased constant Giflib.Streams.Byte_Array := [2, 2, 16#54#, 16#01#, 0];
      Truncated : aliased constant Giflib.Streams.Byte_Array := [2, 2, 16#44#];
      Source : Giflib.Streams.Memory_Source (Bad_Index'Access);
      Truncated_Source : Giflib.Streams.Memory_Source (Truncated'Access);
      Context : Giflib.Internal.LZW.Workspace_Handle;
      Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
      Fault : Giflib.Internal.Ownership.Fault_State;
      Output : Giflib.Streams.Byte_Array (1 .. 2);
      Pixels : Giflib.Pixel_Count := 0;
      Compressed : Giflib.Byte_Count := 0;
      Outcome : Giflib.Results.Result;
   begin
      Prepare (Context, Budget, Fault);
      Giflib.Streams.Open (Source);
      Outcome := Giflib.Internal.Image_Data.Decode_Indices
        (Context, Source, Descriptor_1x2, Two_Color_Palette,
         Giflib.Limits.Default_Limits,
         Pixels, Compressed, Output (1 .. 1), Frame => 7);
      Assert (Outcome.First_Error.Code = Giflib.Errors.LZW_Output_Size_Mismatch,
              "wrong-sized target was not rejected before input");
      Assert (Source.Offset = 0, "wrong-sized target consumed input");

      declare
         One_Pixel : constant Giflib.Internal.Container.Image_Descriptor :=
           (Left => 0, Top => 0, Width => 1, Height => 1, others => <>);
      begin
         Outcome := Giflib.Internal.Image_Data.Decode_Indices
           (Context, Source, One_Pixel, Two_Color_Palette,
            Giflib.Limits.Default_Limits,
            Pixels, Compressed, Output (1 .. 1), Frame => 7);
      end;
      Assert (Outcome.First_Error.Code = Giflib.Errors.Palette_Index_Out_Of_Range,
              "invalid palette index was accepted");
      Assert (Outcome.First_Error.Context.Frame = 7, "palette error lost frame context");

      Pixels := 0;
      Compressed := 0;
      Giflib.Streams.Open (Truncated_Source);
      Outcome := Giflib.Internal.Image_Data.Decode_Indices
        (Context, Truncated_Source, Descriptor_1x2, Two_Color_Palette,
         Giflib.Limits.Default_Limits,
         Pixels, Compressed, Output);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Truncated_Block,
              "truncated compressed sub-block has wrong error");
      Assert (Giflib.Internal.LZW.Release (Context, Budget),
              "malformed-image LZW workspace ledger mismatch");
   end Rejects_Palette_Index_And_Truncation;

   procedure Enforces_Buffer_And_Total_Budgets (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Input : aliased constant Giflib.Streams.Byte_Array := [2, 2, 16#44#, 16#0A#, 0];
      Source : Giflib.Streams.Memory_Source (Input'Access);
      Context : Giflib.Internal.LZW.Workspace_Handle;
      Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
      Fault : Giflib.Internal.Ownership.Fault_State;
      Output : Giflib.Streams.Byte_Array (1 .. 2);
      Constraints : Giflib.Limits.Limit_Set := Giflib.Limits.Default_Limits;
      Pixels : Giflib.Pixel_Count := 1;
      Compressed : Giflib.Byte_Count := 0;
      Outcome : Giflib.Results.Result;
   begin
      Prepare (Context, Budget, Fault);
      Constraints.Max_Total_Decoded_Frame_Pixels := 2;
      Giflib.Streams.Open (Source);
      Outcome := Giflib.Internal.Image_Data.Decode_Indices
        (Context, Source, Descriptor_1x2, Two_Color_Palette, Constraints,
         Pixels, Compressed, Output);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded,
              "total decoded pixel budget was ignored");
      Assert (Outcome.First_Error.Context.Limit = Giflib.Total_Decoded_Pixel_Limit,
              "pixel budget failure lost context");
      Assert (Source.Offset = 0, "pixel budget failure consumed input");

      Constraints := Giflib.Limits.Default_Limits;
      Constraints.Max_Compressed_Bytes := 1;
      Pixels := 0;
      Giflib.Streams.Open (Source);
      Outcome := Giflib.Internal.Image_Data.Decode_Indices
        (Context, Source, Descriptor_1x2, Two_Color_Palette, Constraints,
         Pixels, Compressed, Output);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded,
              "compressed byte budget was ignored");
      Assert (Outcome.First_Error.Context.Limit = Giflib.Compressed_Byte_Limit,
              "compressed byte failure lost context");
      Assert (Giflib.Internal.LZW.Release (Context, Budget),
              "budgeted-image LZW workspace ledger mismatch");
   end Enforces_Buffer_And_Total_Budgets;
end Giflib.Testing.Test_Image_Data;
