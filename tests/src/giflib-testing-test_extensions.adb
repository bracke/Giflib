with AUnit.Assertions;

with Giflib.Animations;
with Giflib.Decoding;
with Giflib.Errors;
with Giflib.Frames;
with Giflib.Internal.Extension_Arithmetic;
with Giflib.Internal.Metadata_Arithmetic;
with Giflib.Limits;
with Giflib.Metadata;
with Giflib.Results;
with Giflib.Streams;
with Giflib.Testing.Assertions;

package body Giflib.Testing.Test_Extensions is
   use AUnit.Assertions;
   use type Giflib.Animations.Loop_State;
   use type Giflib.Decoding.Event_Kind;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Frames.Graphic_Control;
   use type Giflib.Frames.Disposal_Method;
   use type Giflib.Metadata.Extension_Kind;
   use type Giflib.Streams.Byte_Array;

   procedure GCE_Scopes_To_Next_Image (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Plain_Text_Consumes_GCE (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Retains_Ordered_Metadata_And_Loop (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Retained_Indexes_Grow_Boundedly
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Recognizes_Animexts_Loop (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Covers_Retention_Policies_And_Bounds (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Extension_Malformed_And_Budgets_Fail (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Control_Field_Arithmetic_Is_Exact (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Metadata_Arithmetic_Is_Exact (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("extensions");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, GCE_Scopes_To_Next_Image'Access, "extensions.gce.image_scope");
      Register_Routine (T, Plain_Text_Consumes_GCE'Access, "extensions.gce.plain_text_scope");
      Register_Routine (T, Retains_Ordered_Metadata_And_Loop'Access,
                        "extensions.retention_order_and_loop");
      Register_Routine (T, Retained_Indexes_Grow_Boundedly'Access,
                        "extensions.retained_index_growth");
      Register_Routine (T, Recognizes_Animexts_Loop'Access,
                        "extensions.animexts_loop");
      Register_Routine (T, Covers_Retention_Policies_And_Bounds'Access,
                        "extensions.retention_policies_and_bounds");
      Register_Routine (T, Extension_Malformed_And_Budgets_Fail'Access,
                        "extensions.malformed_and_budgets");
      Register_Routine (T, Control_Field_Arithmetic_Is_Exact'Access,
                        "extensions.control_field_arithmetic");
      Register_Routine (T, Metadata_Arithmetic_Is_Exact'Access,
                        "extensions.metadata_arithmetic");
   end Register_Tests;

   procedure Metadata_Arithmetic_Is_Exact (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Control_Field_Arithmetic_Is_Exact (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   function Header_With_Palette return Giflib.Streams.Byte_Array is
   begin
      return
        [71, 73, 70, 56, 57, 97,
         1, 0, 1, 0, 16#80#, 0, 0,
         0, 0, 0, 255, 255, 255];
   end Header_With_Palette;

   function Image_1x1 return Giflib.Streams.Byte_Array is
   begin
      return
        [16#2C#, 0, 0, 0, 0, 1, 0, 1, 0, 0,
         2, 2, 16#44#, 16#01#, 0];
   end Image_1x1;

   procedure GCE_Scopes_To_Next_Image (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Plain_Text_Consumes_GCE (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Retains_Ordered_Metadata_And_Loop (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Retained_Indexes_Grow_Boundedly
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Recognizes_Animexts_Loop
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Covers_Retention_Policies_And_Bounds
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Extension_Malformed_And_Budgets_Fail (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
end Giflib.Testing.Test_Extensions;
