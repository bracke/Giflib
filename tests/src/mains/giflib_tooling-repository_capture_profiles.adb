package body Giflib_Tooling.Repository_Capture_Profiles is
   procedure Visit
     (Profile : Capture_Profile;
      Include_Directory : not null access procedure
        (Relative_Path : String; Required : Boolean);
      Include_File : not null access procedure
        (Relative_Path : String; Required : Boolean)) is
   begin
      Include_Directory ("src", Required => True);
      if Profile = Complete_Repository then
         Include_Directory ("tests/src", Required => True);
         Include_File ("alire.toml", Required => True);
         Include_File ("tests/alire.toml", Required => True);
         Include_File ("giflib.gpr", Required => True);
         Include_File ("tests/giflib_whitebox.gpr", Required => True);
         Include_File ("tests/public_api.gpr", Required => True);
         Include_File ("tests/private_api_rejection.gpr", Required => True);
         Include_File
           ("tests/ownership_safety_rejection.gpr", Required => True);
         Include_File ("tests/unit_tests.gpr", Required => True);
         Include_File ("tests/tools.gpr", Required => True);
         Include_File ("docs/IMPLEMENTATION_PLAN.md", Required => True);
      end if;
   end Visit;
end Giflib_Tooling.Repository_Capture_Profiles;
