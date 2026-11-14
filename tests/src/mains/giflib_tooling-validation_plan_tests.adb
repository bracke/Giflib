with Ada.Strings.Unbounded;

with Giflib_Tooling.Self_Test_Support;
with Giflib_Tooling.Source_Limits;
with Giflib_Tooling.Validation_Plans;
with Giflib_Tooling.Validation_Runner;
with Giflib_Tooling.Work_Budgets;

package body Giflib_Tooling.Validation_Plan_Tests is
   package Check renames Giflib_Tooling.Self_Test_Support;
   package Plans renames Giflib_Tooling.Validation_Plans;
   package Budgets renames Giflib_Tooling.Work_Budgets;

   procedure Run (Root : String) is
      Base : constant Plans.Plan := Plans.Default_Plan;
      Base_Limits : constant Giflib_Tooling.Source_Limits.Analysis_Limits :=
        Plans.Limits_Of (Base);
      Aggregate_Cutoff_Rejected : Boolean := False;
      Invalid_Plan_Rejected : Boolean := False;
      Invalid_Inventory_Rejected : Boolean := False;
      Oversized_Path_Rejected : Boolean := False;
      Oversized_Inventory_Rejected : Boolean := False;
      Duplicate_Inventory_Rejected : Boolean := False;
      Custom_Plan_Accepted : Boolean := False;
      Pipeline_Work_Monotonic : Boolean := True;
      Previous_Work : Natural := 0;
      Report : Validation_Runner.Validation_Report;
      Projects : Plans.Project_Inventory_Vectors.Vector;
      procedure Copy_Project
        (Project_Path : String; Source_Directory : String) is
      begin
         Projects.Append
           (Plans.Project_Inventory'
              (Ada.Strings.Unbounded.To_Unbounded_String (Project_Path),
               Ada.Strings.Unbounded.To_Unbounded_String (Source_Directory)));
      end Copy_Project;
   begin
      Plans.Visit_Projects (Base, Copy_Project'Access);
      declare
         Custom : constant Plans.Plan :=
           Plans.Create
             ("custom-plan.md", "custom-tests", "custom-suite.adb", Projects,
              Base_Limits);
      begin
         Custom_Plan_Accepted :=
           Plans.Documentation_Path_Of (Custom) = "custom-plan.md"
           and then Plans.Test_Directory_Of (Custom) = "custom-tests"
           and then Plans.Suite_Path_Of (Custom) = "custom-suite.adb";
      end;
      declare
         No_Projects : Plans.Project_Inventory_Vectors.Vector;
      begin
         begin
            declare
               Rejected : constant Plans.Plan :=
                 Plans.Create
                   ("plan.md", "tests", "suite.adb", No_Projects,
                    Base_Limits);
               pragma Unreferenced (Rejected);
            begin
               null;
            end;
         exception
            when Input_Error =>
               Invalid_Inventory_Rejected := True;
         end;
      end;
      begin
         declare
            Rejected : constant Plans.Plan :=
              Plans.Create
                (String'(1 .. Plans.Maximum_Path_Length + 1 => 'x'),
                 "tests", "suite.adb", Projects, Base_Limits);
            pragma Unreferenced (Rejected);
         begin
            null;
         end;
      exception
         when Input_Error =>
            Oversized_Path_Rejected := True;
      end;
      declare
         Too_Many : Plans.Project_Inventory_Vectors.Vector := Projects;
      begin
         while Natural (Too_Many.Length) <= Plans.Maximum_Projects loop
            Too_Many.Append (Projects.First_Element);
         end loop;
         begin
            declare
               Rejected : constant Plans.Plan :=
                 Plans.Create
                   ("plan.md", "tests", "suite.adb", Too_Many, Base_Limits);
               pragma Unreferenced (Rejected);
            begin
               null;
            end;
         exception
            when Input_Error =>
               Oversized_Inventory_Rejected := True;
         end;
      end;
      declare
         Duplicated : Plans.Project_Inventory_Vectors.Vector := Projects;
      begin
         Duplicated.Append (Projects.First_Element);
         begin
            declare
               Rejected : constant Plans.Plan :=
                 Plans.Create
                   ("plan.md", "tests", "suite.adb", Duplicated,
                    Base_Limits);
               pragma Unreferenced (Rejected);
            begin
               null;
            end;
         exception
            when Input_Error =>
               Duplicate_Inventory_Rejected := True;
         end;
      end;
      declare
         Limits : Giflib_Tooling.Source_Limits.Analysis_Limits := Base_Limits;
      begin
         Limits.Cache.Maximum_Cache_Work :=
           Limits.Validation.Maximum_Validation_Work + 1;
         begin
            declare
               Rejected : constant Plans.Plan :=
                 Plans.With_Limits (Base, Limits);
               pragma Unreferenced (Rejected);
            begin
               null;
            end;
         exception
            when Input_Error =>
               Invalid_Plan_Rejected := True;
         end;
      end;
      Report := Validation_Runner.Execute (Root, Base);
      for Phase in Validation_Runner.Validation_Phase loop
         Pipeline_Work_Monotonic := Pipeline_Work_Monotonic
           and then Report.Phases (Phase).Completed
           and then Report.Phases (Phase).Work_Before = Previous_Work
           and then Report.Phases (Phase).Work_After >=
             Report.Phases (Phase).Work_Before;
         Previous_Work := Report.Phases (Phase).Work_After;
      end loop;
      declare
         Parent : aliased Budgets.Budget (1);
         Child : Budgets.Budget := Budgets.Child (Parent, 2);
      begin
         Budgets.Charge (Child);
         begin
            Budgets.Charge (Child);
         exception
            when Budgets.Work_Limit_Exceeded =>
               Aggregate_Cutoff_Rejected := True;
         end;
      end;
      Check.Check
        (Custom_Plan_Accepted
         and then Invalid_Inventory_Rejected
         and then Oversized_Path_Rejected
         and then Oversized_Inventory_Rejected
         and then Duplicate_Inventory_Rejected
         and then Invalid_Plan_Rejected
         and then Report.Total_Work = Previous_Work
         and then Pipeline_Work_Monotonic
         and then Aggregate_Cutoff_Rejected,
         "plans validate limits and the runner shares one aggregate budget");
   end Run;
end Giflib_Tooling.Validation_Plan_Tests;
