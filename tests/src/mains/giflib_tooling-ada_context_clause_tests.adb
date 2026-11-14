with Ada.Strings.Unbounded;

with Giflib_Tooling.Ada_Context_Clauses;
with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Self_Test_Support;

package body Giflib_Tooling.Ada_Context_Clause_Tests is
   use Ada.Strings.Unbounded;
   package Check renames Giflib_Tooling.Self_Test_Support;

   procedure Run is
      Units : constant Name_Collections.Name_Vectors.Vector :=
        Ada_Context_Clauses.Units
          ("limited private with Alpha.Beta, Gamma; " &
           "package Sample with Value => True is end Sample;");
   begin
      Check.Check
        (Natural (Units.Length) = 2
         and then To_String (Units (1)) = "alpha.beta"
         and then To_String (Units (2)) = "gamma",
         "context-clause parsing excludes aspect specifications");
   end Run;
end Giflib_Tooling.Ada_Context_Clause_Tests;
