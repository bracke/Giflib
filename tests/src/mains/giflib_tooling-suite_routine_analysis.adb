with Ada.Strings.Unbounded;

with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Source_Events;
with Giflib_Tooling.Scope_Analysis;
with Giflib_Tooling.Suite_Flow;
with Giflib_Tooling.Suite_Source_Selection;

package body Giflib_Tooling.Suite_Routine_Analysis is
   use Ada.Strings.Unbounded;
   use type Giflib_Tooling.Source_Tokens.Token_Kind;
   package Flow renames Giflib_Tooling.Suite_Flow;
   package Selection renames Giflib_Tooling.Suite_Source_Selection;
   package Tokens renames Giflib_Tooling.Source_Tokens;

   function Registers_Test_Routine
     (Parsed : Giflib_Tooling.Source_Model.Parsed_Source;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget) return Boolean
   is
      Result : Boolean := False;
      procedure Analyze
        (Selected : Selection.Selected_Body;
         Items : Tokens.Token_Vectors.Vector;
         Events : Giflib_Tooling.Source_Events.Structural_Event_Vectors.Vector;
         Ranges :
           Giflib_Tooling.Scope_Analysis.Subprogram_Range_Vectors.Vector)
      is
         Parameter_Name : Unbounded_String;

         function Targets_Parameter (Call_Index : Positive) return Boolean is
            Cursor : Positive := Call_Index + 2;
            Depth : Natural := 1;
            Argument_Number : Positive := 1;
            Argument_First : Boolean := True;
         begin
            while Cursor <= Items.Last_Index and then Depth > 0 loop
               if Tokens.Image (Items (Cursor)) = "(" then
                  Depth := Depth + 1;
               elsif Tokens.Image (Items (Cursor)) = ")" then
                  Depth := Depth - 1;
               elsif Depth = 1 and then Tokens.Image (Items (Cursor)) = "," then
                  Argument_Number := Argument_Number + 1;
                  Argument_First := True;
               elsif Depth = 1 and then Argument_First then
                  if Argument_Number = 1
                    and then Tokens.Kind_Of (Items (Cursor)) = Tokens.Identifier
                    and then Tokens.Image (Items (Cursor)) =
                      To_String (Parameter_Name)
                  then
                     return True;
                  elsif Cursor + 2 <= Items.Last_Index
                    and then Tokens.Image (Items (Cursor)) = "test"
                    and then Tokens.Image (Items (Cursor + 1)) = "=>"
                    and then Tokens.Kind_Of
                      (Items (Cursor + 2)) = Tokens.Identifier
                    and then Tokens.Image (Items (Cursor + 2)) =
                      To_String (Parameter_Name)
                  then
                     return True;
                  end if;
                  Argument_First := False;
               end if;
               Cursor := Cursor + 1;
            end loop;
            return False;
         end Targets_Parameter;
      begin
         if not Selected.Found then
            return;
         elsif Selected.First + 3 <= Items.Last_Index
           and then Tokens.Image (Items (Selected.First + 2)) = "("
           and then Tokens.Kind_Of
             (Items (Selected.First + 3)) = Tokens.Identifier
         then
            Parameter_Name := To_Unbounded_String
              (Tokens.Image (Items (Selected.First + 3)));
         else
            return;
         end if;
         declare
            Map : constant Flow.Flow_Map :=
              Flow.Analyze
                (Items, Events, Ranges, Selected.First,
                 Selected.Body_First, Selected.Last);
         begin
            for Index in Selected.Body_First + 1 .. Selected.Last - 1 loop
               if not Flow.Is_Nested (Map, Index)
                 and then Flow.Is_Unconditional (Map, Index)
                 and then Tokens.Image (Items (Index)) = "register_routine"
                 and then Tokens.Image (Items (Index + 1)) = "("
                 and then Targets_Parameter (Index)
                 and then Tokens.Image (Items (Index - 1)) not in
                   "procedure" | "function"
               then
                  Result := True;
                  return;
               end if;
            end loop;
         end;
      end Analyze;
   begin
      Selection.Inspect_Body
        (Parsed, Budget, "register_tests", Selection.Register_Tests_Profile,
         Analyze'Access);
      return Result;
   end Registers_Test_Routine;
end Giflib_Tooling.Suite_Routine_Analysis;
