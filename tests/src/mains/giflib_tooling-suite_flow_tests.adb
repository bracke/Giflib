with Giflib_Tooling.Scope_Analysis;
with Giflib_Tooling.Self_Test_Support;
with Giflib_Tooling.Source_Events;
with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Suite_Flow;
with Giflib_Tooling.Work_Budgets;

package body Giflib_Tooling.Suite_Flow_Tests is
   package Check renames Giflib_Tooling.Self_Test_Support;
   package Scopes renames Giflib_Tooling.Scope_Analysis;
   package Source renames Giflib_Tooling.Source_Model;
   package Flow renames Giflib_Tooling.Suite_Flow;

   function Invalid_Bounds_Are_Empty return Boolean is
      Parsed : constant Source.Parsed_Source :=
        Source.Parse ("procedure Probe is begin null; end Probe;");
      Tokens : Source_Tokens.Token_Vectors.Vector;
      Events : Source_Events.Structural_Event_Vectors.Vector;
      Budget : Giflib_Tooling.Work_Budgets.Budget;
      Ranges : constant Scopes.Subprogram_Range_Vectors.Vector :=
        Scopes.Subprogram_Ranges (Parsed, Budget);
      procedure Capture
        (Value : Source_Tokens.Token_Vectors.Vector;
         Syntax : Source_Events.Structural_Event_Vectors.Vector) is
      begin
         Tokens := Value;
         Events := Syntax;
      end Capture;
   begin
      Source.Inspect_Syntax (Parsed, Capture'Access);
      declare
         Map : constant Flow.Flow_Map :=
           Flow.Analyze
             (Tokens, Events, Ranges, Tokens.First_Index,
              Tokens.First_Index, Natural (Tokens.Last_Index) + 1);
      begin
         return not Flow.Is_Nested (Map, Tokens.First_Index)
           and then not Flow.Is_Unconditional (Map, Tokens.First_Index);
      end;
   exception
      when others =>
         return False;
   end Invalid_Bounds_Are_Empty;

   procedure Run is
      Budget : Giflib_Tooling.Work_Budgets.Budget;
      Anonymous_End_Ranges : constant Scopes.Subprogram_Range_Vectors.Vector :=
        Scopes.Subprogram_Ranges
          (Source.Parse ("procedure Probe is begin null; end;"), Budget);
   begin
      Check.Check
        (Invalid_Bounds_Are_Empty,
         "suite flow rejects token bounds outside the parsed source");
      Check.Check
        (not Anonymous_End_Ranges.Is_Empty
         and then Anonymous_End_Ranges.First_Element.Complete
         and then Anonymous_End_Ranges.First_Element.Last >
           Anonymous_End_Ranges.First_Element.First,
         "anonymous terminal end statements close subprogram ranges");
   end Run;
end Giflib_Tooling.Suite_Flow_Tests;
