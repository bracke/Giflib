package body Giflib_Tooling.Repository_Test_Support is
   use type Giflib_Tooling.Repository_Diagnostics.Reason;
   package Diagnostics renames Giflib_Tooling.Repository_Diagnostics;

   procedure Expect_Reason
     (Action : not null access procedure;
      Expected : Diagnostics.Reason;
      Matched : out Boolean) is
   begin
      Matched := False;
      Action.all;
   exception
      when E : others =>
         if not Diagnostics.Is_Repository_Error (E) then
            raise;
         end if;
         Matched := Diagnostics.Reason_Of (E) = Expected;
   end Expect_Reason;
end Giflib_Tooling.Repository_Test_Support;
