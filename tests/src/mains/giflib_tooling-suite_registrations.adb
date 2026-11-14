with Giflib_Tooling.Scope_Analysis;
with Giflib_Tooling.Source_Events;
with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Suite_Allocation_Discovery;
with Giflib_Tooling.Suite_Flow;
with Giflib_Tooling.Suite_Registration_Syntax;
with Giflib_Tooling.Suite_Registration_Traversal;
with Giflib_Tooling.Suite_Source_Selection;

package body Giflib_Tooling.Suite_Registrations is
   use Ada.Strings.Unbounded;
   use type Giflib_Tooling.Suite_Registration_Syntax.Name_Result_Kind;
   package Flow renames Giflib_Tooling.Suite_Flow;
   package Allocations renames
     Giflib_Tooling.Suite_Allocation_Discovery;
   package Selection renames Giflib_Tooling.Suite_Source_Selection;
   package Names renames Giflib_Tooling.Name_Collections;
   package Syntax renames Giflib_Tooling.Suite_Registration_Syntax;
   package Traversal renames
     Giflib_Tooling.Suite_Registration_Traversal;
   package Tokens renames Giflib_Tooling.Source_Tokens;

   procedure Include
     (Result : in out Registration_Inventory; Unit_Name : String) is
   begin
      if Unit_Name = "" then
         return;
      elsif Names.Contains (Result.Units, Unit_Name) then
         if Length (Result.Duplicate) = 0 then
            Result.Duplicate := To_Unbounded_String (Unit_Name);
         end if;
      else
         Result.Units.Append (To_Unbounded_String (Unit_Name));
      end if;
   end Include;

   function Registrations
     (Parsed : Giflib_Tooling.Source_Model.Parsed_Source;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget)
      return Registration_Inventory
   is
      Result : Registration_Inventory;
      procedure Analyze
        (Selected : Selection.Selected_Body;
         Items : Tokens.Token_Vectors.Vector;
         Events : Giflib_Tooling.Source_Events.Structural_Event_Vectors.Vector;
         Ranges :
           Giflib_Tooling.Scope_Analysis.Subprogram_Range_Vectors.Vector)
      is
         procedure Include_Unit (Unit_Name : String) is
         begin
            Include (Result, Unit_Name);
         end Include_Unit;
      begin
         if not Selected.Found then
            Result.Issue := Suite_Body_Missing;
            return;
         end if;
         declare
            Map : constant Flow.Flow_Map :=
              Flow.Analyze
                (Items, Events, Ranges, Selected.First,
                 Selected.Body_First, Selected.Last);
            Returned_Suite : constant Syntax.Name_Result :=
              Syntax.Returned_Suite_Name (Selected, Items, Map);
         begin
            if Returned_Suite.Kind /= Syntax.Name_Found then
               Result.Issue :=
                 (if Returned_Suite.Kind = Syntax.Name_Ambiguous
                  then Suite_Return_Ambiguous
                  else Suite_Return_Missing);
               return;
            end if;
            Traversal.Visit
              (Selected, Items, Map, Returned_Suite.Value,
               Allocations.Discover (Selected, Items, Map),
               Include_Unit'Access);
         end;
      end Analyze;
   begin
      Selection.Inspect_Body
        (Parsed, Budget, "all_tests", Selection.All_Tests_Profile,
         Analyze'Access);
      return Result;
   end Registrations;
end Giflib_Tooling.Suite_Registrations;
