with Ada.Containers;
with Giflib_Tooling.Model_Storage;
with Giflib_Tooling.Source_Queries;
with Giflib_Tooling.Structural_Event_Builder;
with Giflib_Tooling.Structural_Units;

package body Giflib_Tooling.Structural_Analysis is
   use type Ada.Containers.Count_Type;
   package Budgets renames Giflib_Tooling.Work_Budgets;
   package Event_Builder renames
     Giflib_Tooling.Structural_Event_Builder;
   package Queries renames Giflib_Tooling.Source_Queries;
   package Unit_Analysis renames Giflib_Tooling.Structural_Units;

   procedure Run
     (Tokens : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
      Events : out Giflib_Tooling.Source_Events.Structural_Event_Vectors.Vector;
      Units : out Giflib_Tooling.Source_Units.Program_Unit_Vectors.Vector;
      Clause : out Giflib_Tooling.Source_Units.Separate_Clause;
      Limits : Giflib_Tooling.Source_Limits.Parsing_Limits;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget;
      Storage : in out Giflib_Tooling.Model_Storage_Budgets.Budget)
   is
      procedure Charge_Clause (Amount : Natural) is
      begin
         Giflib_Tooling.Model_Storage.Charge_Separate_Clause
           (Storage, Amount);
      end Charge_Clause;
   begin
      Events.Clear;
      Units.Clear;
      if Tokens.Length >= 3 then
         Event_Builder.Build (Tokens, Events, Limits, Budget, Storage);
         Unit_Analysis.Derive
           (Events, Units, Limits.Maximum_Program_Units, Budget, Storage);
         Clause := Queries.Separate_Clause_Of
           (Tokens, Budget, Charge_Clause'Access);
      end if;
   end Run;

   procedure Analyze
     (Tokens : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
      Events : out Giflib_Tooling.Source_Events.Structural_Event_Vectors.Vector;
      Units : out Giflib_Tooling.Source_Units.Program_Unit_Vectors.Vector;
      Clause : out Giflib_Tooling.Source_Units.Separate_Clause;
      Limits : Giflib_Tooling.Source_Limits.Parsing_Limits :=
        Giflib_Tooling.Source_Limits.Default_Parsing_Limits)
   is
      Budget : Budgets.Budget (Limits.Maximum_Structural_Work);
      Storage : Giflib_Tooling.Model_Storage_Budgets.Budget
        (Limits.Maximum_Model_Storage);
   begin
      Run (Tokens, Events, Units, Clause, Limits, Budget, Storage);
   end Analyze;

   procedure Analyze
     (Tokens : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
      Events : out Giflib_Tooling.Source_Events.Structural_Event_Vectors.Vector;
      Units : out Giflib_Tooling.Source_Units.Program_Unit_Vectors.Vector;
      Clause : out Giflib_Tooling.Source_Units.Separate_Clause;
      Limits : Giflib_Tooling.Source_Limits.Parsing_Limits;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget;
      Storage : in out Giflib_Tooling.Model_Storage_Budgets.Budget)
   is
      Local_Budget : Budgets.Budget :=
        Budgets.Child (Budget, Limits.Maximum_Structural_Work);
   begin
      Run (Tokens, Events, Units, Clause, Limits, Local_Budget, Storage);
   end Analyze;
end Giflib_Tooling.Structural_Analysis;
