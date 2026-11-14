with Giflib_Tooling.Repository_Searches;
with Giflib_Tooling.Validation_Plans;

private package Giflib_Tooling.Validation_Runner is
   type Validation_Phase is
     (Analysis_Building, Static_Boundaries, Architecture_Rules, Transition_Rules,
      Main_Inventories, Registered_Tests);
   type Phase_Report is record
      Completed : Boolean := False;
      Work_Before : Natural := 0;
      Work_After : Natural := 0;
   end record;
   type Phase_Reports is array (Validation_Phase) of Phase_Report;
   type Validation_Report is record
      Phases : Phase_Reports := [others => <>];
      Total_Work : Natural := 0;
   end record;

   function Execute
     (Root : String;
      Configuration : Giflib_Tooling.Validation_Plans.Plan;
      Cleanup_State : access
        Giflib_Tooling.Repository_Searches.Cleanup_Status := null)
      return Validation_Report;

   procedure Run
     (Root : String;
      Configuration : Giflib_Tooling.Validation_Plans.Plan;
      Cleanup_State : access
        Giflib_Tooling.Repository_Searches.Cleanup_Status := null);
end Giflib_Tooling.Validation_Runner;
