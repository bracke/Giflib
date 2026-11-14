with Giflib_Tooling.Self_Test_Support;
with Giflib_Tooling.Token_Patterns;

package body Giflib_Tooling.Token_Pattern_Tests is
   package Check renames Giflib_Tooling.Self_Test_Support;

   procedure Run is
   begin
      Check.Check
        (not Token_Patterns.Contains_Code
           ("-- with Project_Tools.Files;", "with Project_Tools."),
         "Ada comments are not code");
   end Run;
end Giflib_Tooling.Token_Pattern_Tests;
