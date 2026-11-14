with AUnit.Assertions;

with Giflib.Errors;
with Giflib.Internal.Cleanup;
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
   use type Giflib.Errors.Error;
   use type Giflib.Internal.Ownership.Allocation_Status;
   use type Giflib.Streams.Byte_Array;

   procedure Decodes_Into_Caller_Buffer (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Rejects_Palette_Index_And_Truncation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Enforces_Buffer_And_Total_Budgets (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Decode_And_Skip_Share_Prefix_Diagnostics
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   function Two_Color_Palette return Giflib.Palettes.Palette;
   procedure Prepare
     (Context : in out Giflib.Internal.LZW.Workspace_Handle;
      Budget : aliased in out Giflib.Internal.Ownership.Byte_Budget;
      Fault : in out Giflib.Internal.Ownership.Fault_State);

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
      Register_Routine
        (T, Decode_And_Skip_Share_Prefix_Diagnostics'Access,
         "image_data.shared_prefix_diagnostics");
   end Register_Tests;

   procedure Decode_And_Skip_Share_Prefix_Diagnostics
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

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

   procedure Decodes_Into_Caller_Buffer (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Rejects_Palette_Index_And_Truncation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Enforces_Buffer_And_Total_Budgets (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
end Giflib.Testing.Test_Image_Data;
