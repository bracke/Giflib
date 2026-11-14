with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Self_Test_Support;
with Giflib_Tooling.Session_Analysis;
with Giflib_Tooling.Session_Identity;
with Giflib_Tooling.Session_Queries;
with Giflib_Tooling.Session_Types;
with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Work_Budgets;
with Giflib_Tooling.Work_Budgets.Testing;

package body Giflib_Tooling.Transition_Budget_Tests is
   package Check renames Giflib_Tooling.Self_Test_Support;
   package Analysis renames Giflib_Tooling.Session_Analysis;
   package Identity renames Giflib_Tooling.Session_Identity;
   package Queries renames Giflib_Tooling.Session_Queries;
   package Semantics renames Giflib_Tooling.Session_Types;
   package Source renames Giflib_Tooling.Source_Model;
   package Budgets renames Giflib_Tooling.Work_Budgets;
   package Budget_Testing renames Giflib_Tooling.Work_Budgets.Testing;

   procedure Run is
   begin
      declare
         Budget : Budgets.Budget;
         Exhausted : Boolean := False;
      begin
         Budgets.Charge_Scan (Budget, 10);
         Check.Check
           (Budget_Testing.Can_Charge (Budget, Budgets.Maximum_Work - 10)
            and then not Budget_Testing.Can_Charge
              (Budget, Budgets.Maximum_Work - 9),
            "scan charges consume exactly their stated item count");
         Budgets.Charge (Budget, Budgets.Maximum_Work - 10);
         begin
            Budgets.Charge (Budget);
         exception
            when Budgets.Work_Limit_Exceeded =>
               Exhausted := True;
         end;
         Check.Check
           (Exhausted, "budget exhaustion uses its tooling-neutral exception");
      end;

      declare
         Budget : Budgets.Budget (1);
         Empty : Semantics.Type_Classification_Vectors.Vector;
         Exhausted : Boolean := False;
      begin
         begin
            declare
               Ignored : constant Semantics.Type_Classification_Vectors.Vector :=
                 Queries.Package_Type_Context
                   (Source.Parse ("subtype Alias is Decoder;"),
                    Identity.Create_Known ("Decoder"), Empty, Budget);
               pragma Unreferenced (Ignored);
            begin
               null;
            end;
         exception
            when Budgets.Work_Limit_Exceeded =>
               Exhausted := True;
         end;
         Check.Check
           (Exhausted, "context extraction uses its caller's shared budget");
      end;

      declare
         Budget : Budgets.Budget (1);
         Empty : Semantics.Type_Classification_Vectors.Vector;
         Exhausted : Boolean := False;
         procedure Ignore
           (Statement : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
            Session_Names : Giflib_Tooling.Name_Collections.Name_Vectors.Vector) is
         begin
            pragma Unreferenced (Statement, Session_Names);
         end Ignore;
      begin
         begin
            Analysis.Scan
              (Source.Parse ("null;"), Identity.Create_Known ("Decoder"), Empty,
               Budget, Ignore'Access);
         exception
            when Budgets.Work_Limit_Exceeded =>
               Exhausted := True;
         end;
         Check.Check
           (Exhausted, "semantic scanning uses its caller's shared budget");
      end;
   end Run;
end Giflib_Tooling.Transition_Budget_Tests;
