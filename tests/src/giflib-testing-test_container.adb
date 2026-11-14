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

   procedure Descriptor_Arithmetic_Is_Exact (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Geometry_Arithmetic_Is_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Parses_GIF87a_Global_Palette (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Parses_GIF89a_Without_Palette (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Rejects_Signatures_And_Truncation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Rejects_Dimensions_And_Limits (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Accepts_Geometry_Boundaries
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;
end Giflib.Testing.Test_Container;
