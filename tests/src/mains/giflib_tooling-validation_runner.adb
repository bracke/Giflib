with Giflib_Tooling.Architecture;
with Giflib_Tooling.Analysis_Contexts;
with Giflib_Tooling.Boundaries;
with Giflib_Tooling.Repository_Validation;
with Giflib_Tooling.Repository_Snapshots;
with Giflib_Tooling.Repository_Source_Cache;
with Giflib_Tooling.Source_Limits;
with Giflib_Tooling.Transitions;
with Giflib_Tooling.Validation_Storage_Budgets;
with Giflib_Tooling.Work_Budgets;

package body Giflib_Tooling.Validation_Runner is

   procedure Validate_Captured
     (Analysis : in out Giflib_Tooling.Analysis_Contexts.Context;
      Configuration : Giflib_Tooling.Validation_Plans.Plan;
      Report : in out Validation_Report)
   is
      procedure Start
        (Phase : Validation_Phase;
         Work : Giflib_Tooling.Work_Budgets.Budget) is
      begin
         Report.Phases (Phase).Work_Before :=
           Giflib_Tooling.Work_Budgets.Used (Work);
      end Start;
      procedure Finish
        (Phase : Validation_Phase;
         Work : Giflib_Tooling.Work_Budgets.Budget) is
      begin
         Report.Phases (Phase).Work_After :=
           Giflib_Tooling.Work_Budgets.Used (Work);
         Report.Phases (Phase).Completed := True;
      end Finish;
      procedure Validate_Resources
        (Repository : aliased in Giflib_Tooling.Repository_Snapshots.Snapshot;
         Cached_Sources : aliased in
           Giflib_Tooling.Repository_Source_Cache.Cache;
         Work : aliased in out Giflib_Tooling.Work_Budgets.Budget;
         Storage : aliased in out
           Giflib_Tooling.Validation_Storage_Budgets.Budget)
      is
         procedure Execute_Phase (Phase : Validation_Phase) is
         begin
            Start (Phase, Work);
            case Phase is
               when Analysis_Building =>
                  raise Program_Error with
                    "analysis building is completed before validation";
               when Static_Boundaries =>
                  Boundaries.Validate_Static
                    (Repository, Cached_Sources, Work);
               when Architecture_Rules =>
                  Architecture.Validate
                    (Repository, Cached_Sources, Work);
               when Transition_Rules =>
                  Transitions.Validate
                    (Repository, Cached_Sources, Work, Storage);
               when Main_Inventories =>
                  Repository_Validation.Require_Main_Inventories
                    (Repository, Cached_Sources, Configuration, Work);
               when Registered_Tests =>
                  Repository_Validation.Require_Registered_Test_Packages
                    (Repository, Cached_Sources,
                     Giflib_Tooling.Validation_Plans.Test_Directory_Of
                       (Configuration),
                     Giflib_Tooling.Validation_Plans.Suite_Path_Of
                       (Configuration),
                     Work);
            end case;
            Finish (Phase, Work);
         end Execute_Phase;
      begin
         Report.Phases (Analysis_Building) :=
           (Completed => True,
            Work_Before => 0,
            Work_After => Giflib_Tooling.Work_Budgets.Used (Work));
         for Phase in Static_Boundaries .. Registered_Tests loop
            Execute_Phase (Phase);
         end loop;
         Report.Total_Work := Giflib_Tooling.Work_Budgets.Used (Work);
      end Validate_Resources;
   begin
      Giflib_Tooling.Analysis_Contexts.Inspect
        (Analysis, Validate_Resources'Access);
   end Validate_Captured;

   function Execute
     (Root : String;
      Configuration : Giflib_Tooling.Validation_Plans.Plan;
      Cleanup_State : access
        Giflib_Tooling.Repository_Searches.Cleanup_Status := null)
      return Validation_Report
   is
      Limits : constant Giflib_Tooling.Source_Limits.Analysis_Limits :=
        Giflib_Tooling.Validation_Plans.Limits_Of (Configuration);
      Report : Validation_Report;
   begin
      declare
         Analysis : Giflib_Tooling.Analysis_Contexts.Context :=
           Giflib_Tooling.Analysis_Contexts.Build
             (Root, Limits => Limits,
              Cleanup_State => Cleanup_State);
      begin
         Validate_Captured
           (Analysis, Configuration, Report);
      end;
      return Report;
   end Execute;

   procedure Run
     (Root : String;
      Configuration : Giflib_Tooling.Validation_Plans.Plan;
      Cleanup_State : access
        Giflib_Tooling.Repository_Searches.Cleanup_Status := null)
   is
      Report : constant Validation_Report :=
        Execute (Root, Configuration, Cleanup_State);
      pragma Unreferenced (Report);
   begin
      null;
   end Run;
end Giflib_Tooling.Validation_Runner;
