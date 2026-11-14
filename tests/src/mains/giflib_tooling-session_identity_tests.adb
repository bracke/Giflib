with Giflib_Tooling.Self_Test_Support;
with Giflib_Tooling.Session_Identity;

package body Giflib_Tooling.Session_Identity_Tests is
   package Check renames Giflib_Tooling.Self_Test_Support;
   package Identity renames Giflib_Tooling.Session_Identity;
   use type Identity.Identity_Error;

   procedure Run is
      procedure Expect_Invalid
        (Simple_Name : String; Qualified_Name : String; Message : String)
      is
         Result : constant Identity.Creation_Result :=
           Identity.Try_Create (Simple_Name, Qualified_Name);
      begin
         Check.Check
           (not Identity.Succeeded (Result)
            and then Identity.Error_Of (Result) /= Identity.No_Identity_Error,
            Message);
      end Expect_Invalid;
   begin
      declare
         Item : constant Identity.Target :=
           Identity.Create_Known ("Decoder", "Giflib.Decoding.Decoder");
      begin
         Check.Check
           (Identity.Simple_Name (Item) = "decoder"
            and then Identity.Qualified_Name (Item) =
              "giflib.decoding.decoder",
            "target identities are validated and normalized");
      end;
      Expect_Invalid ("", "", "target identities reject empty simple names");
      Expect_Invalid
        ("end", "", "target identities reject reserved simple names");
      Expect_Invalid
        ("decoder", "giflib..decoder",
         "target identities reject malformed qualified names");
      Expect_Invalid
        ("decoder", "giflib.decoding.encoder",
         "target identities reject inconsistent terminal names");
   end Run;
end Giflib_Tooling.Session_Identity_Tests;
