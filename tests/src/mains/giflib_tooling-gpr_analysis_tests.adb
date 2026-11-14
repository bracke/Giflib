with Ada.Strings.Unbounded;

with Giflib_Tooling.GPR_Analysis;
with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Self_Test_Support;

package body Giflib_Tooling.GPR_Analysis_Tests is
   use Ada.Strings.Unbounded;
   package Check renames Giflib_Tooling.Self_Test_Support;
   package GPR renames Giflib_Tooling.GPR_Analysis;

   function Malformed_GPR_Is_Rejected return Boolean is
   begin
      declare
         Ignored : constant Name_Collections.Name_Vectors.Vector :=
           GPR.Attribute_Strings
             ("for Library_Interface use (""unterminated);",
              "Library_Interface");
      begin
         pragma Unreferenced (Ignored);
         return False;
      end;
   exception
      when Input_Error =>
         return True;
   end Malformed_GPR_Is_Rejected;

   procedure Run is
      Attributes : constant Name_Collections.Name_Vectors.Vector :=
        GPR.Attribute_Strings
          ("Library_Interface := (""Decoy""); " &
           "for Library_Interface use (""Actual"");",
           "Library_Interface");
   begin
      Check.Check
        (not GPR.Has_With
           ("-- with ""dependency.gpr"";", "dependency.gpr"),
         "GPR comments do not satisfy imports");
      Check.Check
        (Malformed_GPR_Is_Rejected,
         "unterminated GPR strings are diagnosed without partial parsing");
      Check.Check
        (Natural (Attributes.Length) = 1
         and then To_String (Attributes.First_Element) = "Actual",
         "exact GPR attribute parsing");
   end Run;
end Giflib_Tooling.GPR_Analysis_Tests;
