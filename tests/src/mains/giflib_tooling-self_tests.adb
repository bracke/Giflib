with Giflib_Tooling.Ada_Context_Clause_Tests;
with Giflib_Tooling.Configuration_Tests;
with Giflib_Tooling.GPR_Analysis_Tests;
with Giflib_Tooling.Mutation_Tests;
with Giflib_Tooling.Record_Tests;
with Giflib_Tooling.Repository_Analysis_Tests;
with Giflib_Tooling.Repository_File_Tests;
with Giflib_Tooling.Session_Iterable_Tests;
with Giflib_Tooling.Session_Scope_Tests;
with Giflib_Tooling.Session_State_Tests;
with Giflib_Tooling.Source_Tests;
with Giflib_Tooling.Suite_Flow_Tests;
with Giflib_Tooling.Suite_Registration_Tests;
with Giflib_Tooling.Suite_Routine_Tests;
with Giflib_Tooling.Transition_Tests;
with Giflib_Tooling.Transition_Context_Tests;
with Giflib_Tooling.Transition_Cache_Tests;
with Giflib_Tooling.Token_Pattern_Tests;
with Giflib_Tooling.Validation_Plan_Tests;

package body Giflib_Tooling.Self_Tests is
   procedure Run (Root : String) is
   begin
      Giflib_Tooling.Configuration_Tests.Run;
      Giflib_Tooling.GPR_Analysis_Tests.Run;
      Giflib_Tooling.Ada_Context_Clause_Tests.Run;
      Giflib_Tooling.Token_Pattern_Tests.Run;
      Giflib_Tooling.Record_Tests.Run;
      Giflib_Tooling.Source_Tests.Run;
      Giflib_Tooling.Suite_Registration_Tests.Run;
      Giflib_Tooling.Suite_Routine_Tests.Run;
      Giflib_Tooling.Suite_Flow_Tests.Run;
      Giflib_Tooling.Repository_Analysis_Tests.Run;
      Giflib_Tooling.Repository_File_Tests.Run;
      Giflib_Tooling.Transition_Tests.Run;
      Giflib_Tooling.Transition_Context_Tests.Run;
      Giflib_Tooling.Transition_Cache_Tests.Run;
      Giflib_Tooling.Session_Scope_Tests.Run;
      Giflib_Tooling.Session_State_Tests.Run;
      Giflib_Tooling.Session_Iterable_Tests.Run;
      Giflib_Tooling.Validation_Plan_Tests.Run (Root);
   end Run;

   procedure Run_Mutations (Root : String; Probe : String) is
   begin
      Giflib_Tooling.Mutation_Tests.Run (Root, Probe);
   end Run_Mutations;
end Giflib_Tooling.Self_Tests;
