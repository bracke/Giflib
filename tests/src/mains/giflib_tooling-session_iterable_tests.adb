with Giflib_Tooling.Session_Iterable_Basic_Tests;
with Giflib_Tooling.Session_Iterable_Inheritance_Tests;
with Giflib_Tooling.Session_Iterable_Qualified_Tests;
with Giflib_Tooling.Session_Iterable_Visibility_Tests;

package body Giflib_Tooling.Session_Iterable_Tests is
   procedure Run is
   begin
      Giflib_Tooling.Session_Iterable_Basic_Tests.Run;
      Giflib_Tooling.Session_Iterable_Inheritance_Tests.Run;
      Giflib_Tooling.Session_Iterable_Qualified_Tests.Run;
      Giflib_Tooling.Session_Iterable_Visibility_Tests.Run;
   end Run;
end Giflib_Tooling.Session_Iterable_Tests;
