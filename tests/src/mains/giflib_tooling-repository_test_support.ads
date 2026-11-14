with Giflib_Tooling.Repository_Diagnostics;

private package Giflib_Tooling.Repository_Test_Support is
   procedure Expect_Reason
     (Action : not null access procedure;
      Expected : Giflib_Tooling.Repository_Diagnostics.Reason;
      Matched : out Boolean);
end Giflib_Tooling.Repository_Test_Support;
