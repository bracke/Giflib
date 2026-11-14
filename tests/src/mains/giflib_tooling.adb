with Ada.Exceptions;
with Ada.Text_IO;

with Project_Tools.Release_Checks;

with Giflib_Tooling.Boundaries;
with Giflib_Tooling.Repository_Diagnostics;
with Giflib_Tooling.Repository_Searches;
with Giflib_Tooling.Validation_Plans;
with Giflib_Tooling.Validation_Runner;
with Giflib_Tooling.Work_Budgets;

package body Giflib_Tooling is
   procedure Fail (Message : String) is
   begin
      Project_Tools.Release_Checks.Fail ("giflib tooling: " & Message);
   end Fail;

   procedure Validate (Root : String) is
      package Searches renames Giflib_Tooling.Repository_Searches;
      use type Searches.Cleanup_Status;
      Cleanup_State : aliased Searches.Cleanup_Status :=
        Searches.Cleanup_Complete;
      function With_Cleanup (Message : String) return String is
        (if Cleanup_State = Searches.Cleanup_Failed
         then Message & "; repository directory search cleanup also failed"
         else Message);
      procedure Report_Secondary_Cleanup is
      begin
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "secondary failure: repository directory search cleanup " &
            "also failed");
      exception
         when others =>
            --  Reporting must not replace the active invariant failure.
            null;
      end Report_Secondary_Cleanup;
   begin
      Validation_Runner.Run
        (Root, Validation_Plans.Default_Plan, Cleanup_State'Access);
      Boundaries.Validate_API (Root);
   exception
      when E : Giflib_Tooling.Work_Budgets.Work_Limit_Exceeded =>
         Fail (With_Cleanup (Ada.Exceptions.Exception_Message (E)));
      when E : Input_Error =>
         Fail (With_Cleanup (Ada.Exceptions.Exception_Message (E)));
      when Program_Error =>
         if Cleanup_State = Searches.Cleanup_Failed then
            Report_Secondary_Cleanup;
         end if;
         raise;
      when E : others =>
         if Giflib_Tooling.Repository_Diagnostics.Is_Repository_Error (E) then
            Fail
              (With_Cleanup
                 (Giflib_Tooling.Repository_Diagnostics.Rendered_Message (E)));
         else
            Fail
              (With_Cleanup
                 ("validation raised an unexpected exception: " &
                  Ada.Exceptions.Exception_Information (E)));
         end if;
   end Validate;
end Giflib_Tooling;
